# GitHub Mirror For ATS CI

This directory is the complete source of truth for the GitHub mirror used by
the Apache Traffic Server Jenkins controller.

The mirror exists because cloning directly from `github.com` during Jenkins
fanout had performance problems that could cause PR tests to timeout and fail.
It also makes ATS CI a better citizen of `github.com`'s shared resources.
Instead of making each CI job perform an external clone, GitHub sends webhook
deliveries to the controller, the controller updates local bare mirrors under
`/home/mirror`, and Jenkins jobs clone from:

```text
https://ci.trafficserver.apache.org/mirror/trafficserver.git
https://ci.trafficserver.apache.org/mirror/trafficserver-ci.git
```

The package is intentionally self-contained. If the controller is lost, this
README plus the files in this directory are enough to rebuild the mirror.

## Architecture

```text
GitHub
  |
  | push and pull_request webhooks
  v
https://ci.trafficserver.apache.org/github-mirror-webhook
  |
  | ATS remap
  v
127.0.0.1:9419/github-mirror-webhook
  |
  | signed webhook receiver, running as gitdaemon
  v
/home/mirror/trafficserver.git
/home/mirror/trafficserver-ci.git
  ^
  | read-only bind mount
  |
127.0.0.1:9417/mirror/
  |
  | dedicated httpd container running git-http-backend
  v
https://ci.trafficserver.apache.org/mirror/
  |
  | ATS remap, cache disabled
  v
Jenkins controller and docker agents
```

The supported Jenkins serving path is smart Git HTTP behind ATS. The public
URLs stay under `https://ci.trafficserver.apache.org/mirror/`, but ATS remaps
that path to a dedicated controller-local httpd container on `127.0.0.1:9417`.
The container runs `git-http-backend` and mounts `/home/mirror` read-only.

Static dumb HTTP is not acceptable for the Jenkins fanout path. It cannot
negotiate packs with the client, so many child jobs can repeatedly download
large static pack files and probe missing loose objects. Smart HTTP uses
`git-upload-pack` so each clone/fetch gets a negotiated pack.

`git-daemon` on port 9418 is kept only as a diagnostic or emergency fallback.
Do not use `git://` URLs as the normal Jenkins configuration.

The webhook service only accepts signed GitHub payloads for:

- `apache/trafficserver`
- `apache/trafficserver-ci`

`apache/trafficserver` mirrors heads, tags, and pull request refs. The PR refs
are required because Jenkins PR jobs receive `GITHUB_PR_HEAD_SHA` and then run a
`GitSCM` checkout from the mirror.

`apache/trafficserver-ci` mirrors heads and tags.

## Fresh Controller Install

These steps assume Ubuntu and a controller that serves
`ci.trafficserver.apache.org` through ATS.

### ASF Infra Request

Ask ASF Infra to add the following GitHub webhooks.

```text
Hello ASF Infra,

The Apache Traffic Server project would like GitHub webhooks added for our
Jenkins Git mirror on ci.trafficserver.apache.org.

Payload URL:
  https://ci.trafficserver.apache.org/github-mirror-webhook

Content type:
  application/json

Secret:
  We will generate a webhook secret with:
    github-mirror/bin/generate-webhook-secret.sh
  We will share it with ASF Infra out of band and install it only on the
  Jenkins controller in:
    /etc/trafficserver-github-mirror/github-mirror-webhook.env

Repositories and events:
  apache/trafficserver:
    - ping
    - push
    - pull_request

  apache/trafficserver-ci:
    - ping
    - push

Rationale:
  Our Jenkins jobs run on a fleet of docker hosts behind the controller. The
  jobs currently clone repeatedly from GitHub. We are moving those checkouts to
  a local read-only smart HTTP mirror on the controller. The webhook keeps
  branch and pull request refs current before Jenkins fans work out to the
  docker hosts.

Thanks.
```

### Controller Setup

1. Clone or copy `trafficserver-ci` onto the controller.

   ```bash
   git clone https://github.com/apache/trafficserver-ci.git /tmp/trafficserver-ci
   cd /tmp/trafficserver-ci
   ```

2. Install the mirror package.

   ```bash
   sudo github-mirror/bin/install-controller.sh
   ```

   The installer:

   - installs `git`, `git-daemon-sysvinit`, `docker.io`, `docker-compose`,
     `python3`, `rsync`, and `util-linux`;
   - installs this package to `/opt/trafficserver-ci/github-mirror`;
   - creates/configures `/home/mirror`;
   - creates `/home/mirror/trafficserver.git`;
   - creates `/home/mirror/trafficserver-ci.git`;
   - configures both bare repos with `http.uploadpack=true` and
     `http.receivepack=false`;
   - installs systemd units;
   - installs `/etc/default/git-daemon`;
   - enables the smart HTTP container service;
   - enables the fallback refresh timer.

3. Install the GitHub webhook secret.

   ```bash
   github-mirror/bin/generate-webhook-secret.sh

   sudo install -d -m 0700 /etc/trafficserver-github-mirror
   sudo editor /etc/trafficserver-github-mirror/github-mirror-webhook.env
   ```

   Paste the generated env line into the file:

   ```text
   GITHUB_WEBHOOK_SECRET=<generated secret shared with ASF Infra>
   ```

   Share only the secret value, not the `GITHUB_WEBHOOK_SECRET=` prefix, with
   ASF Infra.

   If the old controller is gone and the previous secret is unavailable,
   generate a new secret with `github-mirror/bin/generate-webhook-secret.sh`
   and ask ASF Infra to update both GitHub webhooks.

   Keep the file root-owned and private:

   ```bash
   sudo chown root:root /etc/trafficserver-github-mirror/github-mirror-webhook.env
   sudo chmod 0600 /etc/trafficserver-github-mirror/github-mirror-webhook.env
   ```

4. Configure ATS remaps.

   Add `github-mirror/ats/remap-snippet.config` before the generic
   `ci.trafficserver.apache.org` Jenkins remap in:

   ```text
   /opt/ats/etc/trafficserver/remap.config
   ```

   Add or update the `/mirror/` remap with
   `github-mirror/ats/mirror-smart-http-remap-snippet.config`. The important
   change is:

   ```text
   https://ci.trafficserver.apache.org/mirror/ -> http://localhost:9417/mirror/
   ```

   Keep `proxy.config.http.cache.http=0`. Keep `hdr_rw_git.config` unless
   testing proves it interferes with smart Git POSTs. Remove the mirror purge
   plugin from this remap. Do not change the docs httpd/container remaps.

   Reload ATS:

   ```bash
   sudo /opt/ats/bin/traffic_ctl config reload
   ```

5. Verify the smart HTTP service.

   ```bash
   sudo systemctl status github-mirror-smart-http.service

   cd /opt/trafficserver-ci/github-mirror/httpd
   sudo docker-compose config
   sudo docker exec github-mirror-smart-http httpd -t

   git ls-remote http://127.0.0.1:9417/mirror/trafficserver.git refs/heads/master
   git ls-remote http://127.0.0.1:9417/mirror/trafficserver-ci.git refs/heads/main
   ```

6. Start the webhook receiver after the secret is installed.

   ```bash
   sudo systemctl restart github-mirror-webhook.service
   sudo systemctl status github-mirror-webhook.service
   ```

7. Confirm the timer and diagnostic git-daemon are active.

   ```bash
   systemctl list-timers github-mirror-fallback.timer
   sudo service git-daemon status
   ```

8. Configure Jenkins top-level jobs.

   For GitHub PR and branch jobs, set `GITHUB_URL` to the ATS mirror URL:

   ```text
   https://ci.trafficserver.apache.org/mirror/trafficserver.git
   ```

   For the GitHub PR top-level job, set `quietPeriod` to `0`. The
   repo-managed top-level PR pipelines wait up to two minutes for the mirrored
   PR head and merge refs before starting child jobs.

9. Verify the public HTTPS mirror and at least one docker host.

   ```bash
   /opt/trafficserver-ci/github-mirror/bin/check-mirror.sh --pr <open-pr-number>

   CONTROLLER=- \
     /opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh \
       --pr <open-pr-number> docker12
   ```

   To verify the exact PR head Jenkins is about to build:

   ```bash
   GITHUB_PR_HEAD_SHA=<sha-from-jenkins-or-github> \
     /opt/trafficserver-ci/github-mirror/bin/check-mirror.sh --pr <open-pr-number>
   ```

### Webhook Update Behavior

The webhook is the primary update path. Every delivery is validated with
`X-Hub-Signature-256` before it can mutate a mirror. `ping` deliveries validate
the endpoint without changing repositories. `push` deliveries update heads and
tags. `pull_request` deliveries for `apache/trafficserver` update only that
PR's `refs/pull/<number>/head` and `refs/pull/<number>/merge` refs.

Every mirror update runs through `update-mirror.sh`, takes a per-repository
`flock`, and finishes with `git update-server-info`. The fallback systemd timer
is only a safety net for missed deliveries. PR correctness comes from the
webhook plus the Jenkins readiness gate: the top-level PR jobs wait for the
mirrored PR head to match `GITHUB_PR_HEAD_SHA` and for the merge ref to exist
before fanout starts.

## Mirror Operations

Initialize or reconfigure the mirrors:

```bash
sudo /opt/trafficserver-ci/github-mirror/bin/init-mirrors.sh
```

Recreate mirrors from scratch:

```bash
sudo /opt/trafficserver-ci/github-mirror/bin/init-mirrors.sh --force
```

Refresh both mirrors manually:

```bash
sudo -u gitdaemon \
  /opt/trafficserver-ci/github-mirror/bin/update-mirror.sh --all
```

Refresh one ATS PR:

```bash
sudo -u gitdaemon \
  /opt/trafficserver-ci/github-mirror/bin/update-mirror.sh trafficserver --pr 12345
```

Check local and public refs:

```bash
/opt/trafficserver-ci/github-mirror/bin/check-mirror.sh --pr 12345
```

Check from docker agents:

```bash
/opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh --pr 12345 docker1 docker12
```

Back up the controller-local configuration:

```bash
sudo /opt/trafficserver-ci/github-mirror/bin/backup-controller-config.sh \
  /secure/backup/location
```

The backup is written to a timestamped directory under the destination, with
absolute paths preserved under `rootfs/`. It includes the webhook secret and
Jenkins job `config.xml` files, so keep the destination private. To restore a
backup onto a rebuilt controller, inspect `MANIFEST.txt`, then run:

```bash
cd /secure/backup/location/<backup-name>
sudo rsync -a rootfs/ /
sudo systemctl daemon-reload
sudo /opt/ats/bin/traffic_ctl config reload
sudo systemctl restart github-mirror-webhook.service
sudo systemctl restart github-mirror-smart-http.service
```

Use `--no-jenkins` to skip Jenkins job configs, or `--no-package` to skip the
installed `/opt/trafficserver-ci/github-mirror` package copy.

Inspect smart HTTP:

```bash
sudo systemctl status github-mirror-smart-http.service
cd /opt/trafficserver-ci/github-mirror/httpd
sudo docker-compose logs --tail=100 github-mirror-smart-http
sudo tail -n 100 /var/log/github-mirror-smart-http/access_log
```

Use `git-daemon` only as a diagnostic fallback:

```bash
git ls-remote git://ci.trafficserver.apache.org/trafficserver.git refs/heads/master
```

## Webhook Testing

After ASF Infra adds the webhook, use the GitHub UI to send a `ping` delivery.
The response should be HTTP 200.

View webhook service logs and ATS access logs:

```bash
journalctl -u github-mirror-webhook.service -f
sudo tail -f /opt/ats/var/log/trafficserver/access.log
```

Local signed ping test:

```bash
secret=$(sudo awk -F= '/^GITHUB_WEBHOOK_SECRET=/ { print $2 }' \
  /etc/trafficserver-github-mirror/github-mirror-webhook.env)
body='{"repository":{"full_name":"apache/trafficserver"}}'
sig=$(SECRET="$secret" BODY="$body" python3 - <<'PY'
import hashlib
import hmac
import os

print(
    "sha256="
    + hmac.new(
        os.environ["SECRET"].encode(),
        os.environ["BODY"].encode(),
        hashlib.sha256,
    ).hexdigest()
)
PY
)

curl -i \
  -H "X-GitHub-Event: ping" \
  -H "X-Hub-Signature-256: ${sig}" \
  --data "${body}" \
  http://127.0.0.1:9419/github-mirror-webhook
```

To test the full public ATS remap path, use the same signed request against the
public endpoint:

```bash
curl -i \
  -H "X-GitHub-Event: ping" \
  -H "X-Hub-Signature-256: ${sig}" \
  --data "${body}" \
  https://ci.trafficserver.apache.org/github-mirror-webhook
```

A bad secret or unsigned payload should return HTTP 401 and must not update any
repository:

```bash
curl -i \
  -H "X-GitHub-Event: ping" \
  -H "X-Hub-Signature-256: sha256=bad" \
  --data "${body}" \
  https://ci.trafficserver.apache.org/github-mirror-webhook
```

Anonymous push attempts must fail:

```bash
GIT_TERMINAL_PROMPT=0 \
  git push https://ci.trafficserver.apache.org/mirror/trafficserver.git \
    HEAD:refs/heads/github-mirror-push-test
```

The expected result is rejection because the bare repositories have
`http.receivepack=false` and the service does not allow receive-pack.

## Jenkins Integration

Jenkins should clone from these URLs:

```text
https://ci.trafficserver.apache.org/mirror/trafficserver.git
https://ci.trafficserver.apache.org/mirror/trafficserver-ci.git
```

For GitHub PR jobs, configure the top-level job's `GITHUB_URL` parameter to:

```text
https://ci.trafficserver.apache.org/mirror/trafficserver.git
```

The repo-managed PR pipeline scripts fetch:

- the target branch;
- only the current PR's `refs/pull/<number>/head`;
- only the current PR's `refs/pull/<number>/merge`.

They also use
`CloneOption(honorRefspec: true, shallow: true, depth: 1000, noTags: true, timeout: 20)`
so Jenkins does not fan out a wildcard PR ref fetch to every child job.

The child jobs intentionally combine narrow refspecs with shallow, no-tags
checkouts. The refspec controls which refs Jenkins asks the mirror for; the
shallow checkout controls how much reachable commit history Git transfers for
those refs. `noTags: true` keeps Jenkins from pulling extra tag-reachable
history that the builds do not need.

PR jobs use `depth: 1000` because they still run Jenkins' local
`PreBuildMerge`. That depth must be high enough for Git to find the merge base
between the PR head and the target branch. If the depth is too low, checkout
should fail during the local merge with shallow-history or missing-ancestor
errors. Raise the depth before disabling shallow clone globally.

The repo-managed top-level PR jobs wait up to two minutes for the mirrored PR
head to match `GITHUB_PR_HEAD_SHA` and for the PR merge ref to exist before
starting child jobs. Set the Jenkins PR top-level job quiet period to `0`.

For branch jobs, configure the top-level branch jobs' `GITHUB_URL` parameter to
the same ATS mirror URL. Child jobs will receive that value from the fanout job.
Branch jobs use shallow, no-tags checkouts with `depth: 1000`. Normal branch
tip builds should have enough history. A manually requested old SHA outside the
shallow window should fail fast instead of falling back to a large full-history
fetch.

## Rollback

The simplest rollback is to bypass the mirror in Jenkins and clone directly
from GitHub again.

1. Point the Jenkins PR and branch top-level job parameters back at GitHub:

   ```text
   https://github.com/apache/trafficserver.git
   https://github.com/apache/trafficserver-ci.git
   ```

2. Re-run or restart the affected Jenkins jobs.

3. If the mirror should not keep updating while GitHub URLs are in use, stop
   the webhook service and fallback timer.

   ```bash
   sudo systemctl stop github-mirror-webhook.service
   sudo systemctl stop github-mirror-fallback.timer
   ```

4. If the smart HTTP endpoint should also be taken offline, stop its service.

   ```bash
   sudo systemctl disable --now github-mirror-smart-http.service
   ```

Rollback does not require deleting `/home/mirror`.

## Troubleshooting

Missing PR ref:

```bash
sudo -u gitdaemon \
  /opt/trafficserver-ci/github-mirror/bin/update-mirror.sh trafficserver --pr <number>
git --git-dir=/home/mirror/trafficserver.git show-ref refs/pull/<number>/head
git --git-dir=/home/mirror/trafficserver.git show-ref refs/pull/<number>/merge
```

Webhook returns 401:

- Confirm ASF Infra and the controller have the same secret.
- Confirm the env file is readable by systemd and not world-readable:

  ```bash
  sudo systemctl cat github-mirror-webhook.service
  sudo ls -l /etc/trafficserver-github-mirror/github-mirror-webhook.env
  ```

Jenkins cannot clone from HTTPS:

- Verify ATS remap order.
- Verify `/mirror/` points to `http://localhost:9417/mirror/`.
- Verify the smart HTTP service is healthy.
- If the service logs say `detected dubious ownership`, rebuild the current
  image so Git trusts the bind-mounted mirror repositories.
- Verify the public URL:

  ```bash
  sudo systemctl status github-mirror-smart-http.service
  cd /opt/trafficserver-ci/github-mirror/httpd
  sudo docker-compose build
  sudo systemctl restart github-mirror-smart-http.service
  sudo docker exec github-mirror-smart-http httpd -t
  git ls-remote https://ci.trafficserver.apache.org/mirror/trafficserver.git refs/heads/master
  ```

Jenkins fetches look like dumb HTTP:

- Confirm ATS is using the smart HTTP remap, not `http://localhost:8080/mirror/`.
- Confirm logs include `git-upload-pack`:

  ```bash
  sudo tail -n 100 /var/log/github-mirror-smart-http/access_log
  ```

Jenkins fetches fail with HTTP 502 after about 60 seconds:

- Rebuild and restart the current smart HTTP image. The supported config gives
  `git-upload-pack` more time to generate large packs during CI fanout.

  ```bash
  cd /opt/trafficserver-ci/github-mirror/httpd
  sudo docker-compose build
  sudo systemctl restart github-mirror-smart-http.service
  ```

Docker hosts cannot reach the mirror:

```bash
/opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh docker12
```

Webhook service will not start:

```bash
journalctl -u github-mirror-webhook.service -n 100 --no-pager
sudo systemctl status github-mirror-webhook.service
```

The service intentionally refuses to start when `GITHUB_WEBHOOK_SECRET` is
unset or still set to `CHANGE_ME`.

## Controller File Inventory

The installer copies this repo-managed package to:

```text
/opt/trafficserver-ci/github-mirror/
```

The key repo-managed files under that directory are:

```text
/opt/trafficserver-ci/github-mirror/ats/remap-snippet.config
/opt/trafficserver-ci/github-mirror/ats/mirror-smart-http-remap-snippet.config
/opt/trafficserver-ci/github-mirror/bin/backup-controller-config.sh
/opt/trafficserver-ci/github-mirror/bin/generate-webhook-secret.sh
/opt/trafficserver-ci/github-mirror/bin/github-mirror-webhook.py
/opt/trafficserver-ci/github-mirror/bin/init-mirrors.sh
/opt/trafficserver-ci/github-mirror/bin/update-mirror.sh
/opt/trafficserver-ci/github-mirror/env/github-mirror-webhook.env.example
/opt/trafficserver-ci/github-mirror/git-daemon/git-daemon.default
/opt/trafficserver-ci/github-mirror/httpd/docker-compose.yml
/opt/trafficserver-ci/github-mirror/httpd/mirror.conf
/opt/trafficserver-ci/github-mirror/systemd/github-mirror-webhook.service
/opt/trafficserver-ci/github-mirror/systemd/github-mirror-fallback.service
/opt/trafficserver-ci/github-mirror/systemd/github-mirror-fallback.timer
/opt/trafficserver-ci/github-mirror/systemd/github-mirror-smart-http.service
```

The installer creates or updates these controller files:

```text
/etc/default/git-daemon
/etc/systemd/system/github-mirror-webhook.service
/etc/systemd/system/github-mirror-fallback.service
/etc/systemd/system/github-mirror-fallback.timer
/etc/systemd/system/github-mirror-smart-http.service
```

The webhook secret lives outside the repo-managed package:

```text
/etc/trafficserver-github-mirror/github-mirror-webhook.env
```

The local bare mirrors live under:

```text
/home/mirror/trafficserver.git
/home/mirror/trafficserver-ci.git
```

The smart HTTP container writes host-mounted logs here:

```text
/var/log/github-mirror-smart-http/
```

ATS needs the webhook and mirror remap entries in:

```text
/opt/ats/etc/trafficserver/remap.config
```

Use these repo snippets as the source of truth for those remaps:

```text
/opt/trafficserver-ci/github-mirror/ats/remap-snippet.config
/opt/trafficserver-ci/github-mirror/ats/mirror-smart-http-remap-snippet.config
```

The mirror remap also references the existing ATS header rewrite file:

```text
/opt/ats/etc/trafficserver/hdr_rw_git.config
```

Jenkins stores the `GITHUB_URL` and `quietPeriod` settings in job XML under:

```text
/opt/jenkins/home/jobs/
```

Check the GitHub PR top-level job and branch top-level job configs there after
a rebuild. Steady-state mirror updates do not require a cron file.
