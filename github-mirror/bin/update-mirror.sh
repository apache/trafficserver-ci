#!/usr/bin/env bash
#
# Update one or more GitHub mirror repositories under /home/mirror.

set -euo pipefail

MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
LOCK_ROOT=${LOCK_ROOT:-${MIRROR_ROOT}/.locks}
LOCK_WAIT=${LOCK_WAIT:-300}
GIT=${GIT:-git}
LOCK_DIR_TO_REMOVE=""

usage() {
  cat <<'EOF'
Usage:
  update-mirror.sh --all
  update-mirror.sh trafficserver [--all|--heads-tags|--pr NUMBER|--delete-pr NUMBER]
  update-mirror.sh trafficserver-ci [--all|--heads-tags]

Environment:
  MIRROR_ROOT   Directory containing *.git mirrors. Default: /home/mirror
  LOCK_ROOT     Directory for flock lock files. Default: $MIRROR_ROOT/.locks
  LOCK_WAIT     Seconds to wait for a repo lock. Default: 300
  GIT           Git executable. Default: git
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

repo_dir_for() {
  case "$1" in
    trafficserver|trafficserver.git)
      printf '%s/trafficserver.git\n' "${MIRROR_ROOT}"
      ;;
    trafficserver-ci|trafficserver-ci.git)
      printf '%s/trafficserver-ci.git\n' "${MIRROR_ROOT}"
      ;;
    *)
      return 1
      ;;
  esac
}

repo_name_for() {
  case "$1" in
    trafficserver|trafficserver.git)
      printf 'trafficserver\n'
      ;;
    trafficserver-ci|trafficserver-ci.git)
      printf 'trafficserver-ci\n'
      ;;
    *)
      return 1
      ;;
  esac
}

validate_pr_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "invalid pull request number: $1"
}

acquire_repo_lock() {
  local repo=$1
  mkdir -p "${LOCK_ROOT}"

  if command -v flock >/dev/null 2>&1; then
    exec 9>"${LOCK_ROOT}/${repo}.lock"
    flock -w "${LOCK_WAIT}" 9 || die "timed out waiting for ${repo} lock"
    return
  fi

  local lock_dir="${LOCK_ROOT}/${repo}.lockdir"
  local deadline=$((SECONDS + LOCK_WAIT))
  while ! mkdir "${lock_dir}" >/dev/null 2>&1; do
    if [ "${SECONDS}" -ge "${deadline}" ]; then
      die "timed out waiting for ${repo} lock"
    fi
    sleep 1
  done
  LOCK_DIR_TO_REMOVE=${lock_dir}
  trap 'if [ -n "${LOCK_DIR_TO_REMOVE:-}" ]; then rm -rf "${LOCK_DIR_TO_REMOVE}"; fi' EXIT
}

fetch_required() {
  local repo_dir=$1
  shift
  log "fetching required refs: $*"
  "${GIT}" --git-dir="${repo_dir}" fetch --prune origin "$@"
}

fetch_optional() {
  local repo_dir=$1
  shift
  log "fetching optional refs: $*"
  if ! "${GIT}" --git-dir="${repo_dir}" fetch origin "$@"; then
    log "optional fetch failed; continuing: $*"
  fi
}

delete_ref() {
  local repo_dir=$1
  local ref=$2
  if "${GIT}" --git-dir="${repo_dir}" show-ref --verify --quiet "${ref}"; then
    log "deleting ${ref}"
    "${GIT}" --git-dir="${repo_dir}" update-ref -d "${ref}"
  else
    log "ref not present, nothing to delete: ${ref}"
  fi
}

update_repo() {
  local requested_repo=$1
  shift

  local repo
  repo=$(repo_name_for "${requested_repo}") || die "unknown repo: ${requested_repo}"

  local repo_dir
  repo_dir=$(repo_dir_for "${repo}") || die "unknown repo: ${repo}"
  [ -d "${repo_dir}" ] || die "mirror does not exist: ${repo_dir}; run init-mirrors.sh first"

  acquire_repo_lock "${repo}"

  local selectors=("$@")
  if [ ${#selectors[@]} -eq 0 ]; then
    selectors=(--all)
  fi

  local did_work=0
  local selector
  while [ ${#selectors[@]} -gt 0 ]; do
    selector=${selectors[0]}
    selectors=("${selectors[@]:1}")

    case "${selector}" in
      --all)
        if [ "${repo}" = "trafficserver" ]; then
          fetch_required "${repo_dir}" \
            '+refs/heads/*:refs/heads/*' \
            '+refs/tags/*:refs/tags/*' \
            '+refs/pull/*:refs/pull/*'
        else
          fetch_required "${repo_dir}" \
            '+refs/heads/*:refs/heads/*' \
            '+refs/tags/*:refs/tags/*'
        fi
        did_work=1
        ;;
      --heads-tags)
        fetch_required "${repo_dir}" \
          '+refs/heads/*:refs/heads/*' \
          '+refs/tags/*:refs/tags/*'
        did_work=1
        ;;
      --pr)
        [ "${repo}" = "trafficserver" ] || die "--pr is only valid for trafficserver"
        [ ${#selectors[@]} -gt 0 ] || die "--pr requires a pull request number"
        local pr_number=${selectors[0]}
        selectors=("${selectors[@]:1}")
        validate_pr_number "${pr_number}"
        fetch_required "${repo_dir}" \
          "+refs/pull/${pr_number}/head:refs/pull/${pr_number}/head"
        fetch_optional "${repo_dir}" \
          "+refs/pull/${pr_number}/merge:refs/pull/${pr_number}/merge"
        did_work=1
        ;;
      --delete-pr)
        [ "${repo}" = "trafficserver" ] || die "--delete-pr is only valid for trafficserver"
        [ ${#selectors[@]} -gt 0 ] || die "--delete-pr requires a pull request number"
        local pr_number=${selectors[0]}
        selectors=("${selectors[@]:1}")
        validate_pr_number "${pr_number}"
        delete_ref "${repo_dir}" "refs/pull/${pr_number}/head"
        delete_ref "${repo_dir}" "refs/pull/${pr_number}/merge"
        did_work=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown selector: ${selector}"
        ;;
    esac
  done

  [ "${did_work}" -eq 1 ] || die "no update work was requested"
  "${GIT}" --git-dir="${repo_dir}" update-server-info
  log "updated ${repo} mirror at ${repo_dir}"
}

if [ $# -eq 0 ]; then
  usage
  exit 2
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
  --all)
    update_repo trafficserver --all
    update_repo trafficserver-ci --all
    ;;
  *)
    repo_arg=$1
    shift
    update_repo "${repo_arg}" "$@"
    ;;
esac
