# GitHub Mirror For ATS CI

This directory is the complete source of truth for the GitHub mirror used by
the Apache Traffic Server Jenkins controller.

The goal is to avoid every Jenkins docker agent cloning directly from GitHub.
GitHub sends webhook deliveries to the controller, the controller updates local
bare mirrors under `/home/mirror`, and Jenkins jobs clone from:

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

## ASF Infra Request

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
  Please generate a webhook secret or coordinate it with us out of band.
  We will install it only on the Jenkins controller in:
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

## Fresh Controller Install

These steps assume Ubuntu and a controller that serves
`ci.trafficserver.apache.org` through ATS.

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
     `python3`, and `util-linux`;
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
   sudo install -d -m 0700 /etc/trafficserver-github-mirror
   sudo editor /etc/trafficserver-github-mirror/github-mirror-webhook.env
   ```

   Set:

   ```text
   GITHUB_WEBHOOK_SECRET=<secret from ASF Infra>
   ```

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

8. Verify the public HTTPS mirror and at least one docker host.

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

## Existing Controller Rollout

1. Commit and merge the repo changes.

2. Pull the merged branch into `/opt/trafficserver-ci` on `controller`.

   ```bash
   ssh controller
   cd /opt/trafficserver-ci
   sudo git pull --ff-only
   ```

3. Install or refresh the controller files.

   ```bash
   sudo github-mirror/bin/install-controller.sh
   ```

   If ASF webhooks are not ready yet, use the interim cron rollout below.

4. Build/start the smart HTTP service and validate httpd.

   ```bash
   sudo systemctl enable --now github-mirror-smart-http.service
   cd /opt/trafficserver-ci/github-mirror/httpd
   sudo docker-compose config
   sudo docker exec github-mirror-smart-http httpd -t
   ```

5. Update the ATS `/mirror/` remap to point at `http://localhost:9417/mirror/`.
   Keep cache disabled and remove the mirror purge plugin from this remap.

   ```bash
   sudo /opt/ats/bin/traffic_ctl config reload
   ```

6. Verify from controller and at least one docker host.

   ```bash
   /opt/trafficserver-ci/github-mirror/bin/check-mirror.sh --pr <open-pr-number>

   CONTROLLER=- \
     /opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh \
       --pr <open-pr-number> docker12
   ```

7. Confirm the smart HTTP logs show Git requests instead of dumb HTTP object
   probing.

   ```bash
   sudo tail -f /var/log/github-mirror-smart-http/access_log
   ```

   Healthy Jenkins clones should include `git-upload-pack` requests. They should
   not produce thousands of loose-object 404s.

8. Run a small PR fanout subset before broadening:

   ```text
   docs
   rocky
   one autest shard
   ```

   Also confirm existing docs URLs still work through the existing docs
   container.

## Interim Cron Rollout

Use this section while ASF Infra is still setting up the GitHub webhooks. The
temporary cron updater fetches heads, tags, and ATS pull request refs every
minute.

1. Install the current `trafficserver-ci` branch on `controller`.

   ```bash
   ssh controller
   git clone https://github.com/apache/trafficserver-ci.git /tmp/trafficserver-ci
   cd /tmp/trafficserver-ci
   ```

   If testing a PR branch before merge, fetch that branch into this checkout
   before running the installer.

2. Install the mirror package but do not start the webhook service or systemd
   fallback timer yet.

   ```bash
   sudo START_WEBHOOK=0 START_FALLBACK_TIMER=0 \
     github-mirror/bin/install-controller.sh
   ```

   This initializes `/home/mirror/trafficserver.git` and
   `/home/mirror/trafficserver-ci.git`, installs the scripts under
   `/opt/trafficserver-ci/github-mirror`, starts diagnostic `git-daemon`, and
   starts the smart HTTP service. Set `START_SMART_HTTP=0` only if you are not
   ready to change the ATS `/mirror/` remap yet.

3. Install the temporary cron file.

   ```bash
   sudo install -o root -g root -m 0644 \
     /opt/trafficserver-ci/github-mirror/cron/github-mirror \
     /etc/cron.d/github-mirror
   sudo systemctl restart cron
   ```

   Check it is installed:

   ```bash
   sudo cat /etc/cron.d/github-mirror
   grep github-mirror /var/log/syslog
   ```

4. Run one manual refresh and verify refs.

   ```bash
   sudo -u gitdaemon \
     /opt/trafficserver-ci/github-mirror/bin/update-mirror.sh --all

   /opt/trafficserver-ci/github-mirror/bin/check-mirror.sh
   ```

   If you have a current open ATS PR number, verify PR refs too:

   ```bash
   /opt/trafficserver-ci/github-mirror/bin/check-mirror.sh --pr <pr-number>
   ```

5. Verify from at least one docker host.

   From any checkout of this repo on a host that can SSH through `controller`:

   ```bash
   github-mirror/bin/check-docker-access.sh --pr <pr-number> docker12
   ```

   From `controller` itself:

   ```bash
   CONTROLLER=- \
     /opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh \
       --pr <pr-number> docker12
   ```

6. Update Jenkins job configuration so the PR and branch top-level jobs pass
   the ATS mirror URL as `GITHUB_URL`. While the temporary one-minute cron is
   active, set the GitHub PR top-level job quiet period to at least 90 seconds
   so the mirror has time to fetch new PR refs before child jobs start.

   ```text
   GITHUB_URL=https://ci.trafficserver.apache.org/mirror/trafficserver.git
   quietPeriod=90
   ```

   Then run a small PR job such as docs or RAT before starting the full build
   fanout.

7. When ASF webhooks are available, install the secret, start the webhook, send
   a GitHub ping delivery, then remove the temporary cron file.

   ```bash
   sudo systemctl restart github-mirror-webhook.service
   sudo rm -f /etc/cron.d/github-mirror
   sudo systemctl restart cron
   sudo systemctl enable --now github-mirror-fallback.timer
   ```

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
The response should be HTTP 200 and the service logs should show `pong`.

View logs:

```bash
journalctl -u github-mirror-webhook.service -f
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

A bad secret or unsigned payload should return HTTP 401 and must not update any
repository:

```bash
curl -i \
  -H "X-GitHub-Event: ping" \
  -H "X-Hub-Signature-256: sha256=bad" \
  --data "${body}" \
  http://127.0.0.1:9419/github-mirror-webhook
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

They also use `CloneOption(honorRefspec: true, timeout: 20)` so Jenkins does
not fan out a wildcard PR ref fetch to every child job.

During the temporary cron rollout, set the top-level PR job quiet period to at
least 90 seconds. Once the webhook is live and verified, the quiet period can
be removed or reduced.

For branch jobs, configure the top-level branch jobs' `GITHUB_URL` parameter to
the same ATS mirror URL. Child jobs will receive that value from the fanout job.
Branch jobs continue using normal branch checkouts from the mirror URL.

## Migrating An Existing Controller

The historical controller may have older cron jobs such as:

```text
root crontab:       */5 * * * * /admin/bin/update-mirrors.sh
/etc/cron.d/mirror: * * * * * mirror /home/mirror/bin/gh-mirror.sh ...
```

During rollout, leave them in place until the webhook has processed real
deliveries and Jenkins has completed at least one PR build from the mirror.

After validation, disable the old jobs and keep only:

```text
github-mirror-fallback.timer
```

Suggested cleanup:

```bash
sudo crontab -e
sudo rm -f /etc/cron.d/mirror
sudo systemctl restart cron
```

Do not delete the old scripts until the new path has run for a few days.

## Rollback

The Jenkins URLs do not need to change for a smart HTTP rollback because the
public `/mirror/` URLs stay the same.

1. Change the ATS `/mirror/` remap back to the previous static backend:

   ```text
   https://ci.trafficserver.apache.org/mirror/ -> http://localhost:8080/mirror/
   ```

2. Reload ATS.

   ```bash
   sudo /opt/ats/bin/traffic_ctl config reload
   ```

3. Stop the smart HTTP service.

   ```bash
   sudo systemctl disable --now github-mirror-smart-http.service
   ```

4. If the mirror update path is also being rolled back, stop webhook updates
   and re-enable the previous cron updater.

   ```bash
   sudo systemctl stop github-mirror-webhook.service
   sudo systemctl stop github-mirror-fallback.timer
   ```

Full rollback to GitHub is still possible by pointing Jenkins job parameters
back at:

```text
https://github.com/apache/trafficserver.git
https://github.com/apache/trafficserver-ci.git
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
