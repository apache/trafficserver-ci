#!/usr/bin/env bash
#
# Smoke-check the local and public mirror endpoints.

set -euo pipefail

MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
PUBLIC_BASE=${PUBLIC_BASE:-https://ci.trafficserver.apache.org/mirror}
GIT=${GIT:-git}
PR_NUMBER=${PR_NUMBER:-}
GITHUB_PR_HEAD_SHA=${GITHUB_PR_HEAD_SHA:-}

usage() {
  cat <<'EOF'
Usage:
  check-mirror.sh [--pr NUMBER]

Environment:
  MIRROR_ROOT   Local mirror root. Default: /home/mirror
  PUBLIC_BASE   Public HTTPS mirror base URL. Default: https://ci.trafficserver.apache.org/mirror
  GIT           Git executable. Default: git
  PR_NUMBER     Optional PR number to verify.
  GITHUB_PR_HEAD_SHA
                Optional expected PR head SHA to compare against --pr.
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

local_ref_sha() {
  local repo=$1
  local ref=$2
  local repo_dir="${MIRROR_ROOT}/${repo}.git"
  "${GIT}" --git-dir="${repo_dir}" rev-parse "${ref}^{commit}"
}

remote_ref_sha() {
  local repo=$1
  local ref=$2
  local url="${PUBLIC_BASE}/${repo}.git"
  local output
  output=$("${GIT}" ls-remote "${url}" "${ref}")
  [ -n "${output}" ] || die "missing public ref ${ref} at ${url}"
  printf '%s\n' "${output}" | awk 'NR == 1 { print $1 }'
}

check_remote_ref() {
  local repo=$1
  local ref=$2
  local url="${PUBLIC_BASE}/${repo}.git"
  remote_ref_sha "${repo}" "${ref}" >/dev/null
  log "public ${url} has ${ref}"
}

check_local_ref trafficserver refs/heads/master
check_local_ref trafficserver-ci refs/heads/main
check_remote_ref trafficserver refs/heads/master
check_remote_ref trafficserver-ci refs/heads/main

if [ -n "${PR_NUMBER}" ]; then
  [[ "${PR_NUMBER}" =~ ^[0-9]+$ ]] || die "invalid PR number: ${PR_NUMBER}"
  pr_head_ref="refs/pull/${PR_NUMBER}/head"
  pr_merge_ref="refs/pull/${PR_NUMBER}/merge"
  check_local_ref trafficserver "${pr_head_ref}"
  check_remote_ref trafficserver "${pr_head_ref}"
  check_local_ref trafficserver "${pr_merge_ref}"
  check_remote_ref trafficserver "${pr_merge_ref}"

  if [ -n "${GITHUB_PR_HEAD_SHA}" ]; then
    local_head_sha=$(local_ref_sha trafficserver "${pr_head_ref}")
    public_head_sha=$(remote_ref_sha trafficserver "${pr_head_ref}")
    [ "${local_head_sha}" = "${GITHUB_PR_HEAD_SHA}" ] ||
      die "local PR head ${local_head_sha} does not match GITHUB_PR_HEAD_SHA=${GITHUB_PR_HEAD_SHA}"
    [ "${public_head_sha}" = "${GITHUB_PR_HEAD_SHA}" ] ||
      die "public PR head ${public_head_sha} does not match GITHUB_PR_HEAD_SHA=${GITHUB_PR_HEAD_SHA}"
    log "PR head matches GITHUB_PR_HEAD_SHA=${GITHUB_PR_HEAD_SHA}"
  fi
fi

log "mirror checks passed"
