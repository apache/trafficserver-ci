#!/usr/bin/env bash
#
# Create or refresh the bare mirrors used by the ATS Jenkins controller.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
MIRROR_USER=${MIRROR_USER:-gitdaemon}
MIRROR_GROUP=${MIRROR_GROUP:-nogroup}
GIT=${GIT:-git}
FORCE=0
FETCH_AFTER_INIT=1

usage() {
  cat <<'EOF'
Usage:
  init-mirrors.sh [--force] [--no-fetch]

Creates/configures:
  /home/mirror/trafficserver.git
  /home/mirror/trafficserver-ci.git

Options:
  --force     Remove existing mirror directories before reinitializing.
  --no-fetch  Configure repositories but do not fetch data.

Environment:
  MIRROR_ROOT   Mirror root. Default: /home/mirror
  MIRROR_USER   Owner for mirror files. Default: gitdaemon
  MIRROR_GROUP  Group for mirror files. Default: nogroup
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

run_as_mirror_user() {
  if [ "$(id -u)" -eq 0 ]; then
    runuser -u "${MIRROR_USER}" -- "$@"
  else
    "$@"
  fi
}

configure_remote() {
  local repo_dir=$1
  local remote_url=$2
  shift 2

  "${GIT}" --git-dir="${repo_dir}" config remote.origin.url "${remote_url}"
  "${GIT}" --git-dir="${repo_dir}" config --unset-all remote.origin.fetch >/dev/null 2>&1 || true

  local refspec
  for refspec in "$@"; do
    "${GIT}" --git-dir="${repo_dir}" config --add remote.origin.fetch "${refspec}"
  done
}

init_repo() {
  local name=$1
  local remote_url=$2
  shift 2

  local repo_dir="${MIRROR_ROOT}/${name}.git"

  if [ "${FORCE}" -eq 1 ] && [ -e "${repo_dir}" ]; then
    log "removing existing ${repo_dir}"
    rm -rf "${repo_dir}"
  fi

  if [ ! -d "${repo_dir}" ]; then
    log "creating ${repo_dir}"
    run_as_mirror_user "${GIT}" init --bare "${repo_dir}"
  fi

  configure_remote "${repo_dir}" "${remote_url}" "$@"
  "${GIT}" --git-dir="${repo_dir}" config http.uploadpack true
  "${GIT}" --git-dir="${repo_dir}" config http.receivepack false
  touch "${repo_dir}/git-daemon-export-ok"

  if [ "$(id -u)" -eq 0 ]; then
    chown -R "${MIRROR_USER}:${MIRROR_GROUP}" "${repo_dir}"
  fi

  log "configured ${name} mirror"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    --no-fetch)
      FETCH_AFTER_INIT=0
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

if ! id "${MIRROR_USER}" >/dev/null 2>&1; then
  die "user ${MIRROR_USER} does not exist; run install-controller.sh first"
fi

install -d -o "${MIRROR_USER}" -g "${MIRROR_GROUP}" -m 0755 "${MIRROR_ROOT}"
install -d -o "${MIRROR_USER}" -g "${MIRROR_GROUP}" -m 0755 "${MIRROR_ROOT}/.locks"

init_repo trafficserver https://github.com/apache/trafficserver.git \
  '+refs/heads/*:refs/heads/*' \
  '+refs/tags/*:refs/tags/*' \
  '+refs/pull/*:refs/pull/*'

init_repo trafficserver-ci https://github.com/apache/trafficserver-ci.git \
  '+refs/heads/*:refs/heads/*' \
  '+refs/tags/*:refs/tags/*'

if [ "${FETCH_AFTER_INIT}" -eq 1 ]; then
  log "fetching initial mirror contents"
  if [ "$(id -u)" -eq 0 ]; then
    run_as_mirror_user env MIRROR_ROOT="${MIRROR_ROOT}" GIT="${GIT}" \
      "${SCRIPT_DIR}/update-mirror.sh" --all
  else
    MIRROR_ROOT="${MIRROR_ROOT}" GIT="${GIT}" "${SCRIPT_DIR}/update-mirror.sh" --all
  fi
fi

log "mirror initialization complete"
