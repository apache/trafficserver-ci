#!/usr/bin/env bash
#
# Install the GitHub mirror package on the Jenkins controller.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

INSTALL_ROOT=${INSTALL_ROOT:-/opt/trafficserver-ci/github-mirror}
MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
MIRROR_USER=${MIRROR_USER:-gitdaemon}
MIRROR_GROUP=${MIRROR_GROUP:-nogroup}
ENV_DIR=${ENV_DIR:-/etc/trafficserver-github-mirror}
ENV_FILE=${ENV_FILE:-${ENV_DIR}/github-mirror-webhook.env}
APT_INSTALL=${APT_INSTALL:-1}
START_WEBHOOK=${START_WEBHOOK:-auto}
START_FALLBACK_TIMER=${START_FALLBACK_TIMER:-1}
INIT_MIRRORS=${INIT_MIRRORS:-1}

usage() {
  cat <<'EOF'
Usage:
  sudo github-mirror/bin/install-controller.sh

Environment:
  INSTALL_ROOT   Installed package path. Default: /opt/trafficserver-ci/github-mirror
  MIRROR_ROOT    Mirror root. Default: /home/mirror
  MIRROR_USER    Mirror owner/service user. Default: gitdaemon
  MIRROR_GROUP   Mirror group. Default: nogroup
  ENV_DIR        Secret/env directory. Default: /etc/trafficserver-github-mirror
  APT_INSTALL    Install required apt packages when set to 1. Default: 1
  INIT_MIRRORS   Run init-mirrors.sh after install when set to 1. Default: 1
  START_WEBHOOK  auto, 1, or 0. Default: auto
  START_FALLBACK_TIMER
                 Enable/start the systemd fallback timer when set to 1. Default: 1
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

render_template() {
  local src=$1
  local dst=$2
  sed \
    -e "s#@INSTALL_ROOT@#${INSTALL_ROOT}#g" \
    -e "s#@MIRROR_ROOT@#${MIRROR_ROOT}#g" \
    -e "s#@MIRROR_USER@#${MIRROR_USER}#g" \
    -e "s#@MIRROR_GROUP@#${MIRROR_GROUP}#g" \
    "${src}" > "${dst}"
}

if [ $# -gt 0 ]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
fi

[ "$(id -u)" -eq 0 ] || die "run as root"

if [ "${APT_INSTALL}" = "1" ]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    git-daemon-sysvinit \
    python3 \
    util-linux
fi

if ! id "${MIRROR_USER}" >/dev/null 2>&1; then
  useradd --system --home-dir /home/gitdaemon --shell /usr/sbin/nologin "${MIRROR_USER}"
fi

install -d -o root -g root -m 0755 "$(dirname "${INSTALL_ROOT}")"
rm -rf "${INSTALL_ROOT}.new"
install -d -o root -g root -m 0755 "${INSTALL_ROOT}.new"
cp -a "${PACKAGE_ROOT}/." "${INSTALL_ROOT}.new/"
find "${INSTALL_ROOT}.new/bin" -type f -name '*.sh' -exec chmod 0755 {} +
find "${INSTALL_ROOT}.new/bin" -type f -name '*.py' -exec chmod 0755 {} +
rm -rf "${INSTALL_ROOT}"
mv "${INSTALL_ROOT}.new" "${INSTALL_ROOT}"
chown -R root:root "${INSTALL_ROOT}"

install -d -o "${MIRROR_USER}" -g "${MIRROR_GROUP}" -m 0755 "${MIRROR_ROOT}"
install -d -o root -g root -m 0700 "${ENV_DIR}"
if [ ! -f "${ENV_FILE}" ]; then
  install -o root -g root -m 0600 \
    "${INSTALL_ROOT}/env/github-mirror-webhook.env.example" \
    "${ENV_FILE}"
  log "created ${ENV_FILE}; set GITHUB_WEBHOOK_SECRET before starting webhook deliveries"
fi

install -o root -g root -m 0644 \
  "${INSTALL_ROOT}/git-daemon/git-daemon.default" \
  /etc/default/git-daemon

tmp_unit=$(mktemp)
render_template "${INSTALL_ROOT}/systemd/github-mirror-webhook.service" "${tmp_unit}"
install -o root -g root -m 0644 "${tmp_unit}" /etc/systemd/system/github-mirror-webhook.service
render_template "${INSTALL_ROOT}/systemd/github-mirror-fallback.service" "${tmp_unit}"
install -o root -g root -m 0644 "${tmp_unit}" /etc/systemd/system/github-mirror-fallback.service
render_template "${INSTALL_ROOT}/systemd/github-mirror-fallback.timer" "${tmp_unit}"
install -o root -g root -m 0644 "${tmp_unit}" /etc/systemd/system/github-mirror-fallback.timer
rm -f "${tmp_unit}"

systemctl daemon-reload
systemctl enable git-daemon.service >/dev/null 2>&1 || true
systemctl restart git-daemon.service >/dev/null 2>&1 || service git-daemon restart

if [ "${INIT_MIRRORS}" = "1" ]; then
  MIRROR_ROOT="${MIRROR_ROOT}" MIRROR_USER="${MIRROR_USER}" MIRROR_GROUP="${MIRROR_GROUP}" \
    "${INSTALL_ROOT}/bin/init-mirrors.sh"
fi

systemctl enable github-mirror-webhook.service
if [ "${START_FALLBACK_TIMER}" = "1" ]; then
  systemctl enable --now github-mirror-fallback.timer
else
  systemctl disable --now github-mirror-fallback.timer >/dev/null 2>&1 || true
fi

if [ "${START_WEBHOOK}" = "1" ] ||
   { [ "${START_WEBHOOK}" = "auto" ] && grep -q '^GITHUB_WEBHOOK_SECRET=' "${ENV_FILE}" &&
     ! grep -q '^GITHUB_WEBHOOK_SECRET=CHANGE_ME' "${ENV_FILE}"; }; then
  systemctl restart github-mirror-webhook.service
else
  log "webhook service installed but not started; configure ${ENV_FILE}, then run:"
  log "  sudo systemctl restart github-mirror-webhook.service"
fi

log "install complete"
