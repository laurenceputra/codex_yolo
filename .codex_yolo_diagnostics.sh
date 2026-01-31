#!/usr/bin/env bash
# Health check and diagnostics for codex_yolo
set -euo pipefail

echo "=== codex_yolo Diagnostics ==="
echo ""

# Version info
echo "📦 Version Information:"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
  echo "  codex_yolo version: $(cat "${SCRIPT_DIR}/VERSION")"
else
  echo "  codex_yolo version: unknown (VERSION file missing)"
fi

# Docker check
echo ""
echo "🐳 Docker Status:"
if command -v docker >/dev/null 2>&1; then
  echo "  ✓ Docker installed: $(docker --version)"
  
  if docker info >/dev/null 2>&1; then
    echo "  ✓ Docker daemon running"
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    echo "  Docker server version: ${docker_version}"
  else
    echo "  ✗ Docker daemon not running"
  fi
  
  if docker buildx version >/dev/null 2>&1; then
    echo "  ✓ Docker buildx available: $(docker buildx version | head -1)"
  else
    echo "  ⚠ Docker buildx not available (builds may be slower)"
  fi
else
  echo "  ✗ Docker not installed"
fi

# Image check
echo ""
echo "🖼️  Image Status:"
IMAGE="${CODEX_YOLO_IMAGE:-codex-cli-yolo:local}"
image_version=""
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "  ✓ Image exists: ${IMAGE}"
  
  image_version=$(docker run --rm --entrypoint cat "${IMAGE}" /opt/codex-version 2>/dev/null || echo "unknown")
  echo "  Codex CLI version in image: ${image_version}"
  
  image_size=$(docker image inspect "${IMAGE}" --format='{{.Size}}' 2>/dev/null || echo "0")
  image_size_mb=$((image_size / 1024 / 1024))
  echo "  Image size: ${image_size_mb} MB"
  
  image_created=$(docker image inspect "${IMAGE}" --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1 || echo "unknown")
  echo "  Image created: ${image_created}"
else
  echo "  ⚠ Image not found: ${IMAGE}"
  echo "    Run 'codex_yolo' to build it"
fi

# Latest version check
echo ""
echo "📡 Latest Version Check:"
if command -v npm >/dev/null 2>&1; then
  latest_version=$(npm view @openai/codex version 2>/dev/null || echo "unknown")
  echo "  Latest @openai/codex: ${latest_version}"
  
  if [[ -n "${image_version}" && "${image_version}" != "unknown" ]]; then
    if [[ "${latest_version}" == "${image_version}" ]]; then
      echo "  ✓ Image is up to date"
    else
      echo "  ⚠ Update available: ${image_version} -> ${latest_version}"
    fi
  fi
else
  echo "  ⚠ npm not available (cannot check latest version)"
fi

# Environment check
echo ""
echo "⚙️  Environment:"
echo "  HOME: ${HOME}"
echo "  Current directory: $(pwd)"
echo "  User: $(id -un) (UID: $(id -u))"
echo "  Group: $(id -gn) (GID: $(id -g))"

# Codex config check
echo ""
echo "🔑 Codex Configuration:"
if [[ -d "${HOME}/.codex" ]]; then
  echo "  ✓ Config directory exists: ${HOME}/.codex"
  if [[ -w "${HOME}/.codex" ]]; then
    echo "  ✓ Config directory writable"
  else
    echo "  ✗ Config directory not writable"
  fi
  
  config_files=$(find "${HOME}/.codex" -type f 2>/dev/null | wc -l)
  echo "  Files in config: ${config_files}"
else
  echo "  ⚠ Config directory missing: ${HOME}/.codex"
  echo "    It will be created on first run"
fi

# Git config check
echo ""
echo "🔧 Git Configuration:"
if [[ -f "${HOME}/.gitconfig" ]]; then
  echo "  ✓ .gitconfig exists"
  
  git_name=$(git config --file "${HOME}/.gitconfig" user.name 2>/dev/null || echo "")
  git_email=$(git config --file "${HOME}/.gitconfig" user.email 2>/dev/null || echo "")
  
  if [[ -n "${git_name}" ]]; then
    echo "  Git user.name: ${git_name}"
  else
    echo "  ⚠ Git user.name not set"
  fi
  
  if [[ -n "${git_email}" ]]; then
    echo "  Git user.email: ${git_email}"
  else
    echo "  ⚠ Git user.email not set"
  fi
else
  echo "  ⚠ .gitconfig not found"
  echo "    Commits will use default identity"
fi

# Disk space check
echo ""
echo "💾 Disk Space:"
workspace_df=$(df -h "$(pwd)" | tail -1)
echo "  Workspace: ${workspace_df}"

# Environment variables
echo ""
echo "🌍 Active Environment Variables:"
env | grep -E '^CODEX_' | sort || echo "  (none set)"

# Summary
echo ""
echo "=== Summary ==="
issues=0

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker is not installed"
  issues=$((issues + 1))
elif ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon is not running"
  issues=$((issues + 1))
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "⚠️  Docker buildx not available (optional but recommended)"
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "ℹ️  Image not built yet (will be built on first run)"
fi

if [[ ! -d "${HOME}/.codex" ]] || [[ ! -w "${HOME}/.codex" ]]; then
  echo "⚠️  Config directory missing or not writable"
  issues=$((issues + 1))
fi

if [[ ${issues} -eq 0 ]]; then
  echo "✅ All critical checks passed!"
  echo ""
  echo "Ready to use codex_yolo. Try: codex_yolo --help"
else
  echo "❌ ${issues} critical issue(s) found"
  echo ""
  echo "Please address the issues above before using codex_yolo"
  exit 1
fi
