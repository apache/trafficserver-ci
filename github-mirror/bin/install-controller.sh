#!/usr/bin/env bash
#
# Install the GitHub mirror package on the Jenkins controller.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

INSTALL_ROOT=${INSTALL_ROOT:-/opt/github-mirror}
MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
MIRROR_USER=${MIRROR_USER:-gitdaemon}
MIRROR_GROUP=${MIRROR_GROUP:-nogroup}
CONFIG_DIR=${CONFIG_DIR:-${INSTALL_ROOT}/config}
ENV_FILE=${ENV_FILE:-${CONFIG_DIR}/github-mirror-webhook.env}
COMPOSE_ENV_FILE=${COMPOSE_ENV_FILE:-${INSTALL_ROOT}/.env}
APT_INSTALL=${APT_INSTALL:-1}
START_COMPOSE=${START_COMPOSE:-auto}
START_FALLBACK_TIMER=${START_FALLBACK_TIMER:-1}
INIT_MIRRORS=${INIT_MIRRORS:-1}
BUILD_IMAGES=${BUILD_IMAGES:-1}

usage() {
  cat <<'EOF'
Usage:
  sudo github-mirror/bin/install-controller.sh

Environment:
  INSTALL_ROOT   Installed package/config path. Default: /opt/github-mirror
  MIRROR_ROOT    Mirror root. Default: /home/mirror
  MIRROR_USER    Mirror owner/service user. Default: gitdaemon
  MIRROR_GROUP   Mirror group. Default: nogroup
  CONFIG_DIR     Config directory. Default: $INSTALL_ROOT/config
  ENV_FILE       Webhook env file. Default: $CONFIG_DIR/github-mirror-webhook.env
  APT_INSTALL    Install required apt packages when set to 1. Default: 1
  INIT_MIRRORS   Run init-mirrors.sh after install when set to 1. Default: 1
  BUILD_IMAGES   Build docker-compose images when set to 1. Default: 1
  START_COMPOSE  auto, 1, or 0. Default: auto
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

secret_is_configured() {
  [ -f "${ENV_FILE}" ] &&
    grep -q '^GITHUB_WEBHOOK_SECRET=' "${ENV_FILE}" &&
    ! grep -q '^GITHUB_WEBHOOK_SECRET=CHANGE_ME' "${ENV_FILE}"
}

copy_if_present() {
  local src=$1
  local dst=$2

  if [ -e "${src}" ] || [ -L "${src}" ]; then
    cp -a "${src}" "${dst}"
    return 0
  fi
  return 1
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
    docker.io \
    docker-compose \
    python3 \
    rsync \
    util-linux
fi

if ! id "${MIRROR_USER}" >/dev/null 2>&1; then
  useradd --system --home-dir /home/gitdaemon --shell /usr/sbin/nologin "${MIRROR_USER}"
fi

if ! getent group "${MIRROR_GROUP}" >/dev/null 2>&1; then
  die "group ${MIRROR_GROUP} does not exist"
fi

install -d -o root -g root -m 0755 "$(dirname "${INSTALL_ROOT}")"
rm -rf "${INSTALL_ROOT}.new"
install -d -o root -g root -m 0755 "${INSTALL_ROOT}.new"
cp -a "${PACKAGE_ROOT}/." "${INSTALL_ROOT}.new/"
find "${INSTALL_ROOT}.new/bin" -type f -name '*.sh' -exec chmod 0755 {} +
find "${INSTALL_ROOT}.new/bin" -type f -name '*.py' -exec chmod 0755 {} +
install -d -o root -g root -m 0700 "${INSTALL_ROOT}.new/config"

if ! copy_if_present "${ENV_FILE}" "${INSTALL_ROOT}.new/config/github-mirror-webhook.env"; then
  # Migrate the pre-Compose secret location if this is an existing controller.
  copy_if_present /etc/trafficserver-github-mirror/github-mirror-webhook.env \
    "${INSTALL_ROOT}.new/config/github-mirror-webhook.env" || \
    install -o root -g root -m 0600 \
      "${INSTALL_ROOT}.new/config/github-mirror-webhook.env.example" \
      "${INSTALL_ROOT}.new/config/github-mirror-webhook.env"
  log "created ${INSTALL_ROOT}.new/config/github-mirror-webhook.env; set GITHUB_WEBHOOK_SECRET before starting webhook deliveries"
fi

if ! copy_if_present "${CONFIG_DIR}/git-daemon.default" "${INSTALL_ROOT}.new/config/git-daemon.default"; then
  if [ -f /etc/default/git-daemon ] && [ ! -L /etc/default/git-daemon ]; then
    copy_if_present /etc/default/git-daemon "${INSTALL_ROOT}.new/config/git-daemon.default" || true
  fi
fi

rm -rf "${INSTALL_ROOT}"
mv "${INSTALL_ROOT}.new" "${INSTALL_ROOT}"
chown -R root:root "${INSTALL_ROOT}"
chmod 0700 "${CONFIG_DIR}"
chmod 0600 "${ENV_FILE}"

mirror_uid=$(id -u "${MIRROR_USER}")
mirror_gid=$(getent group "${MIRROR_GROUP}" | awk -F: '{ print $3 }')
cat > "${COMPOSE_ENV_FILE}" <<EOF
MIRROR_ROOT=${MIRROR_ROOT}
MIRROR_UID=${mirror_uid}
MIRROR_GID=${mirror_gid}
EOF
chmod 0644 "${COMPOSE_ENV_FILE}"

install -d -o "${MIRROR_USER}" -g "${MIRROR_GROUP}" -m 0755 "${MIRROR_ROOT}"
install -d -o "${MIRROR_USER}" -g "${MIRROR_GROUP}" -m 0755 "${MIRROR_ROOT}/.locks"
install -d -o root -g root -m 0755 /var/log/github-mirror-smart-http

ln -sfn "${INSTALL_ROOT}/config/git-daemon.default" /etc/default/git-daemon

# Remove legacy units from the pre-Compose implementation.
systemctl disable --now github-mirror-webhook.service >/dev/null 2>&1 || true
systemctl disable --now github-mirror-smart-http.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/github-mirror-webhook.service
rm -f /etc/systemd/system/github-mirror-smart-http.service

tmp_unit=$(mktemp)
render_template "${INSTALL_ROOT}/systemd/github-mirror.service" "${tmp_unit}"
install -o root -g root -m 0644 "${tmp_unit}" /etc/systemd/system/github-mirror.service
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

if [ "${BUILD_IMAGES}" = "1" ]; then
  (cd "${INSTALL_ROOT}" && docker-compose build github-mirror github-mirror-smart-http)
fi

systemctl enable github-mirror.service
if [ "${START_FALLBACK_TIMER}" = "1" ]; then
  systemctl enable --now github-mirror-fallback.timer
else
  systemctl disable --now github-mirror-fallback.timer >/dev/null 2>&1 || true
fi

if [ "${START_COMPOSE}" = "1" ] ||
   { [ "${START_COMPOSE}" = "auto" ] && secret_is_configured; }; then
  systemctl restart github-mirror.service
else
  log "compose stack installed but not started; configure ${ENV_FILE}, then run:"
  log "  sudo systemctl enable --now github-mirror.service"
fi

log "install complete"
