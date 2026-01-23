#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${CODEX_YOLO_IMAGE:-codex-cli-yolo:local}"
DOCKERFILE="${SCRIPT_DIR}/.codex_yolo.Dockerfile"
WORKSPACE="$(pwd)"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"
USER_NAME="$(id -un)"
GROUP_NAME="$(id -gn)"
CONTAINER_HOME="${CODEX_YOLO_HOME:-/home/codex}"
CONTAINER_WORKDIR="${CODEX_YOLO_WORKDIR:-/workspace}"
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

if [[ "${CODEX_SKIP_VERSION_CHECK:-0}" != "1" ]] && ! docker buildx version >/dev/null 2>&1; then
  echo "Warning: docker buildx is not available; builds may be slower or fail on some systems."
  echo "Install Docker Buildx to improve build reliability: https://docs.docker.com/build/buildx/"
fi

pass_args=()
for arg in "$@"; do
  if [[ "${arg}" == "--pull" ]]; then
    PULL_REQUESTED=1
    continue
  fi
  pass_args+=("${arg}")
done

if [[ "${CONTAINER_HOME}" != /* ]]; then
  echo "Error: CODEX_YOLO_HOME must be an absolute path inside the container."
  exit 1
fi

if [[ "${CONTAINER_WORKDIR}" != /* ]]; then
  echo "Error: CODEX_YOLO_WORKDIR must be an absolute path inside the container."
  exit 1
fi

if [[ "${IMAGE}" != "codex-cli-yolo:local" ]]; then
  echo "Warning: CODEX_YOLO_IMAGE is set to a non-default image; use only images you trust."
fi

# Build the image locally (no community image pull).
build_args=(--build-arg "BASE_IMAGE=${BASE_IMAGE}")
if [[ "${CODEX_BUILD_NO_CACHE:-0}" == "1" ]]; then
  build_args+=(--no-cache)
fi
if [[ "${CODEX_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
  build_args+=(--pull)
fi

latest_version=""
if [[ "${CODEX_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  if command -v npm >/dev/null 2>&1; then
    latest_version="$(npm view @openai/codex version 2>/dev/null || true)"
  else
    latest_version="$(docker run --rm node:20-slim npm view @openai/codex version 2>/dev/null || true)"
  fi
  latest_version="$(printf '%s' "${latest_version}" | tr -d '\n')"
fi

if [[ -n "${latest_version}" ]]; then
  build_args+=(--build-arg "CODEX_VERSION=${latest_version}")
fi

image_exists=0
image_version=""
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  image_exists=1
  image_version="$(docker run --rm "${IMAGE}" cat /opt/codex-version 2>/dev/null || true)"
  image_version="$(printf '%s' "${image_version}" | tr -d '\n')"
fi

need_build=0
if [[ "${CODEX_BUILD_NO_CACHE:-0}" == "1" || "${CODEX_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
  need_build=1
elif [[ "${image_exists}" == "0" ]]; then
  need_build=1
elif [[ -n "${latest_version}" ]]; then
  if [[ -z "${image_version}" || "${latest_version}" != "${image_version}" ]]; then
    need_build=1
  fi
fi

docker_args=(
  --rm -i
  -e HOME="${CONTAINER_HOME}"
  -e TARGET_UID="${USER_ID}"
  -e TARGET_GID="${GROUP_ID}"
  -e TARGET_USER="${USER_NAME}"
  -e TARGET_GROUP="${GROUP_NAME}"
  -e TARGET_HOME="${CONTAINER_HOME}"
  -e CODEX_YOLO_CLEANUP="${CODEX_YOLO_CLEANUP:-1}"
  -v "${WORKSPACE}:${CONTAINER_WORKDIR}"
  -v "${HOME}/.codex:${CONTAINER_HOME}/.codex"
  -w "${CONTAINER_WORKDIR}"
)

if [[ -t 1 ]]; then
  docker_args+=("-t")
fi

if [[ -f "${HOME}/.gitconfig" ]]; then
  docker_args+=("-v" "${HOME}/.gitconfig:${CONTAINER_HOME}/.gitconfig:ro")
fi

if [[ "${CODEX_DRY_RUN:-0}" == "1" ]]; then
  if [[ "${need_build}" == "1" ]]; then
    echo "Dry run: would build image with:"
    printf 'DOCKER_BUILDKIT=1 docker build %q ' "${build_args[@]}"
    printf '%q ' "-t" "${IMAGE}" "-f" "${DOCKERFILE}" "${SCRIPT_DIR}"
    printf '\n'
  fi

  echo "Dry run: would run:"
  printf 'docker run %q ' "${docker_args[@]}"
  printf '%q ' "${IMAGE}"
  if [[ "${#pass_args[@]}" -gt 0 && "${pass_args[0]}" == "login" ]]; then
    printf 'codex '
    printf '%q ' "${pass_args[@]}"
  else
    printf 'codex --yolo --search '
    printf '%q ' "${pass_args[@]}"
  fi
  printf '\n'
  exit 0
fi

# Ensure host config dir exists so Docker doesn’t create it as root.
if ! mkdir -p "${HOME}/.codex"; then
  echo "Error: unable to create ${HOME}/.codex on the host."
  exit 1
fi

if [[ ! -w "${HOME}/.codex" ]]; then
  echo "Error: ${HOME}/.codex is not writable."
  echo "Check permissions or set HOME to a writable directory."
  exit 1
fi

if [[ -z "${latest_version}" && "${image_exists}" == "1" && "${CODEX_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  echo "Warning: could not check latest @openai/codex version; using existing image."
fi

if [[ "${need_build}" == "1" ]]; then
  if [[ -n "${latest_version}" && -n "${image_version}" && "${latest_version}" != "${image_version}" ]]; then
    echo "Updating Codex CLI ${image_version} -> ${latest_version}"
  fi
  # Force BuildKit to avoid the legacy builder deprecation warning.
  DOCKER_BUILDKIT=1 docker build "${build_args[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${SCRIPT_DIR}"
fi

if [[ "${#pass_args[@]}" -gt 0 && "${pass_args[0]}" == "login" ]]; then
  docker run "${docker_args[@]}" "${IMAGE}" codex "${pass_args[@]}"
else
  docker run "${docker_args[@]}" "${IMAGE}" codex --yolo --search "${pass_args[@]}"
fi
