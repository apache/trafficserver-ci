#!/usr/bin/env bash
#
# Install the remote ccache (bazel-remote) on its host, docker11.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

INSTALL_ROOT=${INSTALL_ROOT:-/opt/ccache-remote}
COMPOSE_ENV_FILE=${INSTALL_ROOT}/.env

# Print a setting from an existing install's .env, if there is one.
installed_setting() {
  [ -f "${COMPOSE_ENV_FILE}" ] && sed -n "s/^$1=//p" "${COMPOSE_ENV_FILE}" | tail -n 1
}

# A rerun keeps the installed storage path and size limit unless they are
# passed in, so that changing the client list doesn't reset the size.
CACHE_ROOT=${CACHE_ROOT:-$(installed_setting CACHE_ROOT || true)}
CACHE_ROOT=${CACHE_ROOT:-/var/lib/ccache-remote}
CACHE_MAX_SIZE_GIB=${CACHE_MAX_SIZE_GIB:-$(installed_setting CACHE_MAX_SIZE_GIB || true)}
CACHE_MAX_SIZE_GIB=${CACHE_MAX_SIZE_GIB:-60}
CACHE_USER=${CACHE_USER:-ccache-remote}
CACHE_PORT=9090
UFW_COMMENT=ccache-remote
ALLOWED_CLIENTS=${ALLOWED_CLIENTS:-${PACKAGE_ROOT}/config/allowed-clients.txt}
CONFIGURE_UFW=${CONFIGURE_UFW:-1}
START_SERVICE=${START_SERVICE:-1}

usage() {
  cat <<'EOF'
Usage:
  sudo ccache-remote/bin/install.sh

Environment:
  INSTALL_ROOT        Installed package path. Default: /opt/ccache-remote
  CACHE_ROOT          Cache storage directory. Default: the installed value,
                      else /var/lib/ccache-remote
  CACHE_USER          System user that owns the cache. Default: ccache-remote
  CACHE_MAX_SIZE_GIB  bazel-remote size limit in GiB. Default: the installed
                      value, else 60
  ALLOWED_CLIENTS     Addresses allowed through ufw to port 9090.
                      Default: ccache-remote/config/allowed-clients.txt
  CONFIGURE_UFW       Sync the ufw rules when set to 1. Default: 1
  START_SERVICE       Enable and (re)start the service when set to 1. Default: 1
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

allowed_addresses() {
  sed -e 's/#.*//' "${ALLOWED_CLIENTS}" | awk 'NF { print $1 }'
}

# Only bare IPv4 addresses: ufw stores 1.2.3.4/32 as 1.2.3.4, so a CIDR entry
# would never match its rule and every other rerun would delete it.
check_allowed_clients() {
  local addr bad=0
  for addr in $(allowed_addresses); do
    if ! [[ ${addr} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      log "error: ${ALLOWED_CLIENTS}: '${addr}' is not a bare IPv4 address"
      bad=1
    fi
  done
  [ "${bad}" = 0 ] || exit 1
}

# bazel-remote has no authentication, so ufw is the only thing keeping the
# writable cache off the internet. Refuse to run without it enforcing.
check_ufw_enforcing() {
  local status
  status=$(ufw status verbose 2>/dev/null) || die "cannot read ufw status"
  grep -q '^Status: active' <<<"${status}" || die "ufw is not active"
  grep -q '^Default: deny (incoming)' <<<"${status}" || die "ufw does not deny incoming connections by default"
}

install_package() {
  if ! id -u "${CACHE_USER}" >/dev/null 2>&1; then
    log "Creating system user ${CACHE_USER}"
    useradd --system --no-create-home --shell /usr/sbin/nologin "${CACHE_USER}"
  fi

  install -d -o "${CACHE_USER}" -g "${CACHE_USER}" -m 0750 "${CACHE_ROOT}"
  install -d -m 0755 "${INSTALL_ROOT}" "${INSTALL_ROOT}/config"
  install -m 0644 "${PACKAGE_ROOT}/docker-compose.yml" "${PACKAGE_ROOT}/README.md" "${INSTALL_ROOT}/"
  install -m 0644 "${ALLOWED_CLIENTS}" "${INSTALL_ROOT}/config/allowed-clients.txt"

  cat > "${COMPOSE_ENV_FILE}" <<EOF
CACHE_UID=$(id -u "${CACHE_USER}")
CACHE_GID=$(id -g "${CACHE_USER}")
CACHE_ROOT=${CACHE_ROOT}
CACHE_MAX_SIZE_GIB=${CACHE_MAX_SIZE_GIB}
EOF

  sed -e "s#@INSTALL_ROOT@#${INSTALL_ROOT}#g" \
    "${PACKAGE_ROOT}/systemd/ccache-remote.service" > /etc/systemd/system/ccache-remote.service
  systemctl daemon-reload
}

# Make the ufw rules for port 9090 match the allowed client list: add the
# missing addresses and delete rules for addresses no longer listed.
sync_ufw() {
  local wanted existing addr
  wanted=$(allowed_addresses | sort -u)
  existing=$(ufw show added | sed -n "s/^ufw allow from \([^ ]*\) to any port ${CACHE_PORT} proto tcp comment '${UFW_COMMENT}'$/\1/p" | sort -u)

  for addr in $(comm -13 <(printf '%s\n' "${existing}") <(printf '%s\n' "${wanted}")); do
    log "ufw: allowing ${addr}"
    ufw allow from "${addr}" to any port "${CACHE_PORT}" proto tcp comment "${UFW_COMMENT}" >/dev/null
  done
  for addr in $(comm -23 <(printf '%s\n' "${existing}") <(printf '%s\n' "${wanted}")); do
    log "ufw: removing ${addr}"
    ufw delete allow from "${addr}" to any port "${CACHE_PORT}" proto tcp >/dev/null
  done
}

start_service() {
  systemctl enable ccache-remote.service >/dev/null
  systemctl restart ccache-remote.service

  local i
  for i in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:${CACHE_PORT}/status" >/dev/null 2>&1; then
      log "ccache-remote is up:"
      curl -fsS "http://127.0.0.1:${CACHE_PORT}/status" >&2
      return 0
    fi
    sleep 2
  done
  die "bazel-remote did not answer on port ${CACHE_PORT}; see: journalctl -u ccache-remote"
}

main() {
  case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    usage
    exit 1
    ;;
  esac

  [ "$(id -u)" -eq 0 ] || die "run as root"
  [ -f "${ALLOWED_CLIENTS}" ] || die "missing ${ALLOWED_CLIENTS}"
  command -v docker-compose >/dev/null || die "docker-compose is not installed"
  check_allowed_clients
  check_ufw_enforcing

  install_package
  if [ "${CONFIGURE_UFW}" = 1 ]; then
    sync_ufw
  fi
  if [ "${START_SERVICE}" = 1 ]; then
    start_service
  fi
}

main "$@"
