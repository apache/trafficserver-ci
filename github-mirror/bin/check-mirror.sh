#!/usr/bin/env bash
#
# Smoke-check the local and public mirror endpoints.

set -euo pipefail

MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
PUBLIC_BASE=${PUBLIC_BASE:-https://ci.trafficserver.apache.org/mirror}
GIT=${GIT:-git}
PR_NUMBER=${PR_NUMBER:-}

usage() {
  cat <<'EOF'
Usage:
  check-mirror.sh [--pr NUMBER]

Environment:
  MIRROR_ROOT   Local mirror root. Default: /home/mirror
  PUBLIC_BASE   Public HTTPS mirror base URL. Default: https://ci.trafficserver.apache.org/mirror
  GIT           Git executable. Default: git
  PR_NUMBER     Optional PR number to verify.
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "error: $*"
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
      die "unknown argument: $1"
      ;;
  esac
  shift
done

check_local_ref() {
  local repo=$1
  local ref=$2
  local repo_dir="${MIRROR_ROOT}/${repo}.git"
  [ -d "${repo_dir}" ] || die "missing local mirror: ${repo_dir}"
  "${GIT}" --git-dir="${repo_dir}" show-ref --verify --quiet "${ref}" ||
    die "missing local ref ${ref} in ${repo}"
  log "local ${repo} has ${ref}"
}

check_remote_ref() {
  local repo=$1
  local ref=$2
  local url="${PUBLIC_BASE}/${repo}.git"
  local output
  output=$("${GIT}" ls-remote "${url}" "${ref}")
  [ -n "${output}" ] || die "missing public ref ${ref} at ${url}"
  log "public ${url} has ${ref}"
}

check_local_ref trafficserver refs/heads/master
check_local_ref trafficserver-ci refs/heads/main
check_remote_ref trafficserver refs/heads/master
check_remote_ref trafficserver-ci refs/heads/main

if [ -n "${PR_NUMBER}" ]; then
  [[ "${PR_NUMBER}" =~ ^[0-9]+$ ]] || die "invalid PR number: ${PR_NUMBER}"
  check_local_ref trafficserver "refs/pull/${PR_NUMBER}/head"
  check_remote_ref trafficserver "refs/pull/${PR_NUMBER}/head"
fi

log "mirror checks passed"
