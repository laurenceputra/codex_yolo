#!/bin/sh
set -eu

TARGET_UID="${TARGET_UID:-1000}"
TARGET_GID="${TARGET_GID:-1000}"
TARGET_USER="${TARGET_USER:-codex}"
TARGET_GROUP="${TARGET_GROUP:-codex}"
TARGET_HOME="${TARGET_HOME:-/home/codex}"
CLEANUP="${CODEX_YOLO_CLEANUP:-1}"
DEFAULT_AGENTS_TEMPLATE="${DEFAULT_AGENTS_TEMPLATE:-/etc/codex/default-AGENTS.md}"

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
  if [ -d "${TARGET_HOME}" ]; then
    useradd -M -u "${TARGET_UID}" -g "${TARGET_GID}" -s /bin/sh -d "${TARGET_HOME}" "${TARGET_USER}"
  else
    useradd -u "${TARGET_UID}" -g "${TARGET_GID}" -s /bin/sh -d "${TARGET_HOME}" "${TARGET_USER}"
  fi
fi

mkdir -p "${TARGET_HOME}/.codex" /etc/sudoers.d

TARGET_AGENTS_FILE="${TARGET_HOME}/.codex/AGENTS.md"
if [ ! -f "${TARGET_AGENTS_FILE}" ] && [ -f "${DEFAULT_AGENTS_TEMPLATE}" ]; then
  cp "${DEFAULT_AGENTS_TEMPLATE}" "${TARGET_AGENTS_FILE}"
fi

chown -R "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}" 2>/dev/null || true

printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${TARGET_USER}" > /etc/sudoers.d/90-codex
chmod 0440 /etc/sudoers.d/90-codex

# Extract git user.name and user.email from .gitconfig if it exists
# and set them as environment variables so Codex CLI uses them for commits
if [ -f "${TARGET_HOME}/.gitconfig" ]; then
  GIT_USER_NAME="$(git config -f "${TARGET_HOME}/.gitconfig" user.name 2>/dev/null || true)"
  GIT_USER_EMAIL="$(git config -f "${TARGET_HOME}/.gitconfig" user.email 2>/dev/null || true)"

  if [ -n "${GIT_USER_NAME}" ]; then
    export GIT_AUTHOR_NAME="${GIT_USER_NAME}"
    export GIT_COMMITTER_NAME="${GIT_USER_NAME}"
  fi

  if [ -n "${GIT_USER_EMAIL}" ]; then
    export GIT_AUTHOR_EMAIL="${GIT_USER_EMAIL}"
    export GIT_COMMITTER_EMAIL="${GIT_USER_EMAIL}"
  fi
fi

if [ "$#" -eq 0 ]; then
  gosu "${TARGET_UID}:${TARGET_GID}" /bin/sh
  exit $?
fi

gosu "${TARGET_UID}:${TARGET_GID}" "$@"
status=$?
exit "${status}"
