#!/bin/sh
set -eu

TARGET_UID="${TARGET_UID:-1000}"
TARGET_GID="${TARGET_GID:-1000}"
TARGET_USER="${TARGET_USER:-codex}"
TARGET_GROUP="${TARGET_GROUP:-codex}"
TARGET_HOME="${TARGET_HOME:-/home/codex}"
CLEANUP="${CODEX_YOLO_CLEANUP:-1}"

cleanup() {
  if [ "${CLEANUP}" = "1" ] || [ "${CLEANUP}" = "true" ]; then
    if [ -d /workspace ]; then
      chown -R "${TARGET_UID}:${TARGET_GID}" /workspace 2>/dev/null || true
    fi
  fi
}

trap 'cleanup' EXIT

case "${TARGET_HOME}" in
  /*) ;;
  *) TARGET_HOME="/home/codex" ;;
esac

if getent group "${TARGET_GID}" >/dev/null 2>&1; then
  TARGET_GROUP="$(getent group "${TARGET_GID}" | cut -d: -f1)"
else
  if getent group "${TARGET_GROUP}" >/dev/null 2>&1; then
    TARGET_GROUP="codex-${TARGET_GID}"
  fi
  groupadd -g "${TARGET_GID}" "${TARGET_GROUP}"
fi

if getent passwd "${TARGET_UID}" >/dev/null 2>&1; then
  TARGET_USER="$(getent passwd "${TARGET_UID}" | cut -d: -f1)"
  if command -v usermod >/dev/null 2>&1; then
    usermod -d "${TARGET_HOME}" "${TARGET_USER}" >/dev/null 2>&1 || true
  fi
else
  if getent passwd "${TARGET_USER}" >/dev/null 2>&1; then
    TARGET_USER="codex-${TARGET_UID}"
  fi
  useradd -u "${TARGET_UID}" -g "${TARGET_GID}" -s /bin/sh -d "${TARGET_HOME}" "${TARGET_USER}"
fi

mkdir -p "${TARGET_HOME}/.codex" /etc/sudoers.d
chown -R "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}" 2>/dev/null || true

printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${TARGET_USER}" > /etc/sudoers.d/90-codex
chmod 0440 /etc/sudoers.d/90-codex

if [ "$#" -eq 0 ]; then
  gosu "${TARGET_UID}:${TARGET_GID}" /bin/sh
  exit $?
fi

gosu "${TARGET_UID}:${TARGET_GID}" "$@"
status=$?
exit "${status}"
