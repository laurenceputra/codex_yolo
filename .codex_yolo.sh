#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="codex-cli-yolo:local"
DOCKERFILE="${SCRIPT_DIR}/.codex_yolo.Dockerfile"
WORKSPACE="$(pwd)"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"
CONTAINER_HOME="/home/codex"
BASE_IMAGE="${CODEX_BASE_IMAGE:-node:20-slim}"
PULL_REQUESTED=0

install_hint=""
case "$(uname -s)" in
  Darwin)
    install_hint="Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
    ;;
  Linux)
    install_hint="Install Docker Engine: https://docs.docker.com/engine/install/"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    install_hint="Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
    ;;
  *)
    install_hint="Install Docker: https://docs.docker.com/get-docker/"
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH."
  echo "${install_hint}"
  exit 127
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker is installed but the daemon is not running."
  echo "Start Docker Desktop or the Docker Engine service, then try again."
  echo "${install_hint}"
  exit 1
fi

pass_args=()
for arg in "$@"; do
  if [[ "${arg}" == "--pull" ]]; then
    PULL_REQUESTED=1
    continue
  fi
  pass_args+=("${arg}")
done

# Build the image locally (no community image pull).
build_args=(--build-arg "BASE_IMAGE=${BASE_IMAGE}")
if [[ "${CODEX_BUILD_NO_CACHE:-0}" == "1" ]]; then
  build_args+=(--no-cache)
fi
if [[ "${CODEX_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
  build_args+=(--pull)
fi

# Force BuildKit to avoid the legacy builder deprecation warning.
DOCKER_BUILDKIT=1 docker build "${build_args[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${SCRIPT_DIR}"

# Ensure host config dir exists so Docker doesn’t create it as root.
mkdir -p "${HOME}/.codex"

docker_args=(
  --rm -it
  -u "${USER_ID}:${GROUP_ID}"
  -e HOME="${CONTAINER_HOME}"
  -v "${WORKSPACE}:/workspace"
  -v "${HOME}/.codex:${CONTAINER_HOME}/.codex"
  -w /workspace
)

if [[ -f "${HOME}/.gitconfig" ]]; then
  docker_args+=("-v" "${HOME}/.gitconfig:${CONTAINER_HOME}/.gitconfig:ro")
fi

docker run "${docker_args[@]}" "${IMAGE}" codex --yolo --search "${pass_args[@]}"
