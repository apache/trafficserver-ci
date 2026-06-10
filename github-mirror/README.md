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
  |
  | httpd export under /mirror/ plus git-daemon on 9418
  v
Jenkins controller and docker agents
```

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
  a local read-only mirror on the controller. The webhook keeps branch and pull
  request refs current before Jenkins fans work out to the docker hosts.

Thanks.
```

## Fresh Controller Install

These steps assume Ubuntu and a controller that will serve
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

   - installs `git`, `git-daemon-sysvinit`, `python3`, and `util-linux`;
   - installs this package to `/opt/trafficserver-ci/github-mirror`;
   - creates/configures `/home/mirror`;
   - creates `/home/mirror/trafficserver.git`;
   - creates `/home/mirror/trafficserver-ci.git`;
   - installs systemd units;
   - installs `/etc/default/git-daemon`;
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

4. Configure the HTTPS webhook endpoint in ATS.

   Add `github-mirror/ats/remap-snippet.config` before the generic
   `ci.trafficserver.apache.org` Jenkins remap in:

   ```text
   /opt/ats/etc/trafficserver/remap.config
   ```

   Reload ATS:

   ```bash
   sudo /opt/ats/bin/traffic_ctl config reload
   ```

5. Export `/home/mirror` as `/mirror/`.

   If the controller already has httpd serving `/mirror/`, keep that setup.
   For a fresh controller, use `github-mirror/httpd/mirror.conf` as the
   reference config for the httpd instance behind ATS. The updater runs
   `git update-server-info`, so a static HTTP export is sufficient.

6. Start the webhook receiver.

   ```bash
   sudo systemctl restart github-mirror-webhook.service
   sudo systemctl status github-mirror-webhook.service
   ```

7. Confirm the timer and git-daemon are active.

   ```bash
   systemctl list-timers github-mirror-fallback.timer
   sudo service git-daemon status
   ```

## Interim Cron Rollout

Use this section while ASF Infra is still setting up the GitHub webhooks. The
cron updater keeps the mirrors fresh enough for Jenkins by fetching heads, tags,
and ATS pull request refs every five minutes.

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
   `/opt/trafficserver-ci/github-mirror`, and starts `git-daemon`.

3. Install the temporary cron file.

   ```bash
   sudo install -o root -g root -m 0644 \
     /opt/trafficserver-ci/github-mirror/cron/github-mirror \
     /etc/cron.d/github-mirror
   sudo systemctl restart cron
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
   github-mirror/bin/check-docker-access.sh docker12
   ```

   From `controller` itself:

   ```bash
   CONTROLLER=- \
     /opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh docker12
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

7. Watch the cron updater and Jenkins checkouts.

   ```bash
   grep github-mirror /var/log/syslog
   git ls-remote https://ci.trafficserver.apache.org/mirror/trafficserver.git \
     refs/heads/master
   ```

8. When ASF webhooks are available, install the secret, start the webhook, send
   a GitHub ping delivery, then remove the temporary cron file.

   ```bash
   sudo systemctl restart github-mirror-webhook.service
   sudo rm -f /etc/cron.d/github-mirror
   sudo systemctl restart cron
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

When running that command directly on the controller, use:

```bash
CONTROLLER=- /opt/trafficserver-ci/github-mirror/bin/check-docker-access.sh docker12
```

## Webhook Testing

After ASF Infra adds the webhook, use the GitHub UI to send a `ping` delivery.
The response should be HTTP 200 and the service logs should show `pong`.

View logs:

```bash
journalctl -u github-mirror-webhook.service -f
```

A bad secret or unsigned payload should return HTTP 401 and must not update any
repository.

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

The top-level pipeline passes that value to child jobs. During the temporary
cron rollout, set the top-level PR job quiet period to at least 90 seconds. Once
the webhook is live and verified, the quiet period can be removed or reduced.

For branch jobs, configure the top-level branch jobs' `GITHUB_URL` parameter to
the same ATS mirror URL. Child jobs will receive that value from the fanout job.

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

1. Stop webhook updates.

   ```bash
   sudo systemctl stop github-mirror-webhook.service
   sudo systemctl stop github-mirror-fallback.timer
   ```

2. Point Jenkins job parameters back at GitHub:

   ```text
   https://github.com/apache/trafficserver.git
   https://github.com/apache/trafficserver-ci.git
   ```

3. If needed, re-enable the previous cron updater.

Rollback does not require deleting `/home/mirror`.

## Troubleshooting

Missing PR ref:

```bash
sudo -u gitdaemon \
  /opt/trafficserver-ci/github-mirror/bin/update-mirror.sh trafficserver --pr <number>
git --git-dir=/home/mirror/trafficserver.git show-ref refs/pull/<number>/head
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
- Verify the httpd `/mirror/` export.
- Verify the public URL:

  ```bash
  git ls-remote https://ci.trafficserver.apache.org/mirror/trafficserver.git refs/heads/master
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
