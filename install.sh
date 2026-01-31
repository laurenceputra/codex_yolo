#!/usr/bin/env bash
set -euo pipefail

REPO="${CODEX_YOLO_REPO:-laurenceputra/codex_yolo}"
BRANCH="${CODEX_YOLO_BRANCH:-main}"
INSTALL_DIR="${CODEX_YOLO_DIR:-$HOME/.codex_yolo}"
PROFILE="${CODEX_YOLO_PROFILE:-}"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to install codex_yolo."
  exit 127
fi

raw_base="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

detect_os() {
  local uname_out os_id os_like
  uname_out="$(uname -s 2>/dev/null || true)"
  case "${uname_out}" in
    Darwin)
      echo "macos"
      return
      ;;
    Linux)
      if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
        echo "wsl"
        return
      fi
      if [[ -r /etc/os-release ]]; then
        read -r os_id os_like < <(. /etc/os-release && printf '%s %s\n' "${ID:-}" "${ID_LIKE:-}")
        if [[ "${os_id}" == "ubuntu" || "${os_id}" == "debian" || "${os_like}" == *debian* ]]; then
          echo "debian"
          return
        fi
        if [[ "${os_id}" == "fedora" || "${os_id}" == "rhel" || "${os_id}" == "centos" || "${os_like}" == *rhel* || "${os_like}" == *fedora* ]]; then
          echo "rhel"
          return
        fi
        if [[ "${os_id}" == "arch" || "${os_like}" == *arch* ]]; then
          echo "arch"
          return
        fi
      fi
      echo "linux"
      return
      ;;
  esac
  echo "unknown"
}

print_docker_guidance() {
  local platform missing_buildx=0
  platform="$(detect_os)"

  if command -v docker >/dev/null 2>&1; then
    if ! docker buildx version >/dev/null 2>&1; then
      missing_buildx=1
    fi
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed. codex_yolo uses Docker to build and run."
    case "${platform}" in
      macos)
        echo "Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
        echo "Or consider Colima: https://github.com/abiosoft/colima"
        ;;
      debian)
        echo "Install Docker Engine (apt): https://docs.docker.com/engine/install/ubuntu/"
        ;;
      rhel)
        echo "Install Docker Engine (dnf/yum): https://docs.docker.com/engine/install/centos/"
        ;;
      arch)
        echo "Install Docker Engine (pacman): https://docs.docker.com/engine/install/archlinux/"
        ;;
      wsl)
        echo "Install Docker Desktop with WSL2 integration: https://docs.docker.com/desktop/wsl/"
        ;;
      *)
        echo "Install Docker Engine: https://docs.docker.com/engine/install/"
        ;;
    esac
    echo "After installing Docker, verify buildx: https://docs.docker.com/build/buildx/working-with-buildx/"

    if ! command -v sudo >/dev/null 2>&1; then
      echo "No sudo detected. Consider rootless Docker: https://docs.docker.com/engine/security/rootless/"
    fi
    return
  fi

  if [[ "${missing_buildx}" -eq 1 ]]; then
    echo "Docker is installed, but buildx is missing."
    echo "Enable or install buildx: https://docs.docker.com/build/buildx/working-with-buildx/"
  fi
}

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
curl -fsSL "${raw_base}/.codex_yolo_entrypoint.sh" -o "${INSTALL_DIR}/.codex_yolo_entrypoint.sh"
curl -fsSL "${raw_base}/.codex_yolo_diagnostics.sh" -o "${INSTALL_DIR}/.codex_yolo_diagnostics.sh"
curl -fsSL "${raw_base}/.dockerignore" -o "${INSTALL_DIR}/.dockerignore" 2>/dev/null || true
curl -fsSL "${raw_base}/VERSION" -o "${INSTALL_DIR}/VERSION"
curl -fsSL "${raw_base}/.codex_yolo_completion.bash" -o "${INSTALL_DIR}/.codex_yolo_completion.bash" 2>/dev/null || true
curl -fsSL "${raw_base}/.codex_yolo_completion.zsh" -o "${INSTALL_DIR}/.codex_yolo_completion.zsh" 2>/dev/null || true
curl -fsSL "${raw_base}/.codex_yolo.conf.example" -o "${INSTALL_DIR}/.codex_yolo.conf.example" 2>/dev/null || true
curl -fsSL "${raw_base}/EXAMPLES.md" -o "${INSTALL_DIR}/EXAMPLES.md" 2>/dev/null || true

chmod +x "${INSTALL_DIR}/.codex_yolo.sh"
chmod +x "${INSTALL_DIR}/.codex_yolo_diagnostics.sh"

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
  printf '\n%s\n' "${source_line}" >> "${profile_path}"
fi

print_docker_guidance

echo "Installed to ${INSTALL_DIR}."
echo ""
echo "Optional: Enable shell completion:"
echo "  Bash: source \"${INSTALL_DIR}/.codex_yolo_completion.bash\""
echo "  Zsh:  source \"${INSTALL_DIR}/.codex_yolo_completion.zsh\""
echo ""
echo "To start using codex_yolo:"
echo "  1. Restart your shell or run: source \"${profile_path}\""
echo "  2. Run: codex_yolo"
echo ""
echo "For examples and help, see: ${INSTALL_DIR}/EXAMPLES.md"
echo "For configuration options: ${INSTALL_DIR}/.codex_yolo.conf.example"
