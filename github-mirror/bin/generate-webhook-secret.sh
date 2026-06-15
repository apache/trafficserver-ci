#!/usr/bin/env bash
#
# Generate a high-entropy GitHub webhook secret for the ATS CI mirror receiver.

set -euo pipefail

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
    return
  fi

  od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
  printf '\n'
}

secret=$(generate_secret)

cat <<EOF
GITHUB_WEBHOOK_SECRET=${secret}

Add this to:
  /etc/trafficserver-github-mirror/github-mirror-webhook.env

Share only the secret value with ASF Infra:
  ${secret}
EOF
