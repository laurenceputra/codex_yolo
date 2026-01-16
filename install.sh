#!/usr/bin/env bash
set -euo pipefail

REPO="${CODEX_YOLO_REPO:-laurenceputra/codex_yolo}"
BRANCH="${CODEX_YOLO_BRANCH:-main}"
INSTALL_DIR="${CODEX_YOLO_DIR:-$HOME/.codex_yolo}"
PROFILE="${CODEX_YOLO_PROFILE:-}"
NONINTERACTIVE="${NONINTERACTIVE:-0}"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to install codex_yolo."
  exit 127
fi

raw_base="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

detect_profile() {
  if [[ -n "${PROFILE}" ]]; then
    echo "${PROFILE}"
    return
  fi

  if [[ -n "${ZDOTDIR:-}" ]]; then
    PROFILE="${ZDOTDIR}/.zshrc"
  elif [[ "${SHELL:-}" == */zsh ]]; then
    PROFILE="${HOME}/.zshrc"
  elif [[ "${SHELL:-}" == */bash ]]; then
    PROFILE="${HOME}/.bashrc"
  else
    PROFILE="${HOME}/.profile"
  fi

  echo "${PROFILE}"
}

profile_path="$(detect_profile)"

mkdir -p "${INSTALL_DIR}"

curl -fsSL "${raw_base}/.codex_yolo.sh" -o "${INSTALL_DIR}/.codex_yolo.sh"
curl -fsSL "${raw_base}/.codex_yolo.Dockerfile" -o "${INSTALL_DIR}/.codex_yolo.Dockerfile"
chmod +x "${INSTALL_DIR}/.codex_yolo.sh"

cat > "${INSTALL_DIR}/env" <<EOF
# shellcheck shell=bash
codex_yolo() {
  "${INSTALL_DIR}/.codex_yolo.sh" "\$@"
}
EOF

source_line="source \"${INSTALL_DIR}/env\""
if [[ ! -f "${profile_path}" ]]; then
  touch "${profile_path}"
fi

if ! grep -Fqs "${source_line}" "${profile_path}"; then
  if [[ "${NONINTERACTIVE}" == "1" ]]; then
    printf '\n%s\n' "${source_line}" >> "${profile_path}"
  else
    echo "Add codex_yolo to ${profile_path}? [Y/n]"
    read -r reply
    if [[ -z "${reply}" || "${reply}" =~ ^[Yy]$ ]]; then
      printf '\n%s\n' "${source_line}" >> "${profile_path}"
    else
      echo "Skipped shell profile update. You can add this line manually:"
      echo "${source_line}"
    fi
  fi
fi

echo "Installed to ${INSTALL_DIR}."
echo "Restart your shell or run: source \"${profile_path}\""
echo "Then run: codex_yolo"
