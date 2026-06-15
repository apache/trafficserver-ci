#!/usr/bin/env bash
#
# Back up controller-local configuration needed to restore the ATS CI mirror.

set -euo pipefail

INCLUDE_JENKINS=${INCLUDE_JENKINS:-1}
INCLUDE_PACKAGE=${INCLUDE_PACKAGE:-1}
DRY_RUN=0
BACKUP_NAME=${BACKUP_NAME:-}
DESTINATION=

usage() {
  cat <<'EOF'
Usage:
  sudo backup-controller-config.sh [options] DESTINATION

Creates DESTINATION/github-mirror-controller-<host>-<timestamp>/ with a
path-preserving rootfs/ tree and MANIFEST.txt.

Options:
  --name NAME       Use NAME instead of the generated backup directory name.
  --no-jenkins     Do not include Jenkins job config.xml files.
  --no-package     Do not include /opt/trafficserver-ci/github-mirror files.
  --dry-run        Show what rsync would copy without writing files.
  -h, --help       Show this help.

Environment:
  BACKUP_NAME      Default backup directory name.
  INCLUDE_JENKINS  Include Jenkins job config.xml files. Default: 1
  INCLUDE_PACKAGE  Include the installed github-mirror package. Default: 1

DESTINATION may be a local path or an rsync remote such as host:/path. The
destination contains the webhook secret, so use a private, access-controlled
location.
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
    --name)
      shift
      [ $# -gt 0 ] || die "--name requires a value"
      BACKUP_NAME=$1
      ;;
    --no-jenkins)
      INCLUDE_JENKINS=0
      ;;
    --no-package)
      INCLUDE_PACKAGE=0
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [ -z "${DESTINATION}" ] || die "only one DESTINATION is supported"
      DESTINATION=$1
      ;;
  esac
  shift
done

[ -n "${DESTINATION}" ] || {
  usage >&2
  exit 1
}

command -v rsync >/dev/null 2>&1 || die "rsync is required"

if [ -z "${BACKUP_NAME}" ]; then
  host=$(hostname -s 2>/dev/null || hostname)
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  BACKUP_NAME="github-mirror-controller-${host}-${timestamp}"
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
file_list="${tmpdir}/files-from"
missing_list="${tmpdir}/missing"
manifest="${tmpdir}/MANIFEST.txt"
: > "${file_list}"
: > "${missing_list}"

add_existing_path() {
  local path=$1

  if [ -e "${path}" ] || [ -L "${path}" ]; then
    printf '%s\0' "${path#/}" >> "${file_list}"
  else
    printf '%s\n' "${path}" >> "${missing_list}"
  fi
}

add_tree() {
  local path=$1

  if [ ! -d "${path}" ]; then
    printf '%s\n' "${path}" >> "${missing_list}"
    return
  fi

  while IFS= read -r -d '' item; do
    add_existing_path "${item}"
  done < <(find "${path}" \( -type f -o -type l \) -print0)
}

add_jenkins_job_configs() {
  local jobs_root=/opt/jenkins/home/jobs

  if [ ! -d "${jobs_root}" ]; then
    printf '%s\n' "${jobs_root}" >> "${missing_list}"
    return
  fi

  while IFS= read -r -d '' item; do
    add_existing_path "${item}"
  done < <(find "${jobs_root}" -type f -name config.xml -print0)
}

if [ "${INCLUDE_PACKAGE}" = "1" ]; then
  add_tree /opt/trafficserver-ci/github-mirror
fi

add_existing_path /etc/default/git-daemon
add_existing_path /etc/systemd/system/github-mirror-webhook.service
add_existing_path /etc/systemd/system/github-mirror-fallback.service
add_existing_path /etc/systemd/system/github-mirror-fallback.timer
add_existing_path /etc/systemd/system/github-mirror-smart-http.service
add_existing_path /etc/trafficserver-github-mirror/github-mirror-webhook.env
add_existing_path /opt/ats/etc/trafficserver/remap.config
add_existing_path /opt/ats/etc/trafficserver/hdr_rw_git.config

if [ "${INCLUDE_JENKINS}" = "1" ]; then
  add_existing_path /opt/jenkins/home/config.xml
  add_jenkins_job_configs
fi

[ -s "${file_list}" ] || die "no files found to back up"

target="${DESTINATION%/}/${BACKUP_NAME}"
if [[ "${target}" != *:* ]] && [ "${DRY_RUN}" = "0" ]; then
  install -d -m 0700 "${target}/rootfs"
fi

{
  printf 'ATS CI GitHub mirror controller backup\n'
  printf 'Created UTC: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Host: %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'Backup name: %s\n' "${BACKUP_NAME}"
  printf 'Destination: %s\n' "${target}"
  printf '\n'
  printf 'WARNING: this backup includes the GitHub webhook secret if it exists.\n'
  printf 'Keep the backup in a private, access-controlled location.\n'
  printf '\n'
  printf 'Restore example:\n'
  printf '  sudo rsync -a rootfs/ /\n'
  printf '  sudo systemctl daemon-reload\n'
  printf '  sudo /opt/ats/bin/traffic_ctl config reload\n'
  printf '  sudo systemctl restart github-mirror-webhook.service\n'
  printf '  sudo systemctl restart github-mirror-smart-http.service\n'
  printf '\n'
  printf 'Files:\n'
  tr '\0' '\n' < "${file_list}" | sed 's#^#/#'
  if [ -s "${missing_list}" ]; then
    printf '\nMissing paths skipped:\n'
    cat "${missing_list}"
  fi
} > "${manifest}"

rsync_args=(-a --relative --from0 --files-from="${file_list}")
if [ "${DRY_RUN}" = "1" ]; then
  rsync_args+=(--dry-run --itemize-changes)
fi

rsync "${rsync_args[@]}" / "${target}/rootfs/"
rsync_manifest_args=(-a)
if [ "${DRY_RUN}" = "1" ]; then
  rsync_manifest_args+=(--dry-run --itemize-changes)
fi
rsync "${rsync_manifest_args[@]}" "${manifest}" "${target}/MANIFEST.txt"

if [ "${DRY_RUN}" = "1" ]; then
  log "dry run complete for ${target}"
else
  log "backup written to ${target}"
fi
if [ -s "${missing_list}" ]; then
  log "some optional paths were missing; see MANIFEST.txt"
fi
