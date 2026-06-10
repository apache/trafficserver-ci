#!/usr/bin/env bash
#
# Verify mirror access from Jenkins docker hosts.

set -euo pipefail

CONTROLLER=${CONTROLLER:-controller}
PUBLIC_BASE=${PUBLIC_BASE:-https://ci.trafficserver.apache.org/mirror}
PR_NUMBER=${PR_NUMBER:-}
GITHUB_PR_HEAD_SHA=${GITHUB_PR_HEAD_SHA:-}

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
  GITHUB_PR_HEAD_SHA
               Optional expected PR head SHA to compare against --pr.
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
    "PUBLIC_BASE=$(printf '%q' "${PUBLIC_BASE}") PR_NUMBER=$(printf '%q' "${PR_NUMBER}") GITHUB_PR_HEAD_SHA=$(printf '%q' "${GITHUB_PR_HEAD_SHA}") bash -s" <<'REMOTE_CHECK'
set -e
require_ref() {
  repo=$1
  ref=$2
  output=$(git ls-remote "$PUBLIC_BASE/${repo}.git" "$ref")
  if [ -z "$output" ]; then
    echo "missing ${repo} ${ref}" >&2
    exit 1
  fi
  printf '%s\n' "$output" | awk 'NR == 1 { print $1 }'
}

require_ref trafficserver refs/heads/master >/dev/null
require_ref trafficserver-ci refs/heads/main >/dev/null
if [ -n "$PR_NUMBER" ]; then
  pr_head_sha=$(require_ref trafficserver "refs/pull/${PR_NUMBER}/head")
  require_ref trafficserver "refs/pull/${PR_NUMBER}/merge" >/dev/null
  if [ -n "$GITHUB_PR_HEAD_SHA" ] && [ "$pr_head_sha" != "$GITHUB_PR_HEAD_SHA" ]; then
    echo "PR head ${pr_head_sha} does not match GITHUB_PR_HEAD_SHA=${GITHUB_PR_HEAD_SHA}" >&2
    exit 1
  fi
fi
REMOTE_CHECK
done

printf 'docker mirror access checks passed\n' >&2
