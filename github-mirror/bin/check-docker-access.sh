#!/usr/bin/env bash
#
# Verify mirror access from Jenkins docker hosts.

set -euo pipefail

CONTROLLER=${CONTROLLER:-controller}
PUBLIC_BASE=${PUBLIC_BASE:-https://ci.trafficserver.apache.org/mirror}
PR_NUMBER=${PR_NUMBER:-}

usage() {
  cat <<'EOF'
Usage:
  check-docker-access.sh [--pr NUMBER] docker1 [docker2 ...]

Runs git ls-remote checks on each docker host through the controller SSH hop.

Environment:
  CONTROLLER   SSH ProxyJump host used to reach docker hosts. Default: controller
               Set to empty or "-" when running directly on the controller.
  PUBLIC_BASE  Public HTTPS mirror base URL. Default: https://ci.trafficserver.apache.org/mirror
  PR_NUMBER    Optional PR number to verify.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pr)
      shift
      [ $# -gt 0 ] || die "--pr requires a number"
      PR_NUMBER=$1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
  shift
done

[ $# -gt 0 ] || die "provide at least one docker host"

for docker_host in "$@"; do
  printf 'checking %s via %s\n' "${docker_host}" "${CONTROLLER}" >&2
  ssh_args=(-o BatchMode=yes)
  if [ -n "${CONTROLLER}" ] && [ "${CONTROLLER}" != "-" ]; then
    ssh_args+=(-J "${CONTROLLER}")
  fi
  ssh "${ssh_args[@]}" "${docker_host}" \
    "PUBLIC_BASE=$(printf '%q' "${PUBLIC_BASE}") PR_NUMBER=$(printf '%q' "${PR_NUMBER}") bash -s" <<'REMOTE_CHECK'
set -e
git ls-remote "$PUBLIC_BASE/trafficserver.git" refs/heads/master >/dev/null
git ls-remote "$PUBLIC_BASE/trafficserver-ci.git" refs/heads/main >/dev/null
if [ -n "$PR_NUMBER" ]; then
  git ls-remote "$PUBLIC_BASE/trafficserver.git" "refs/pull/${PR_NUMBER}/head" >/dev/null
fi
REMOTE_CHECK
done

printf 'docker mirror access checks passed\n' >&2
