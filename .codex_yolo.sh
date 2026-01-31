#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration file if it exists
# Priority: SCRIPT_DIR/config < ~/.codex_yolo/config < env vars
if [[ -f "${SCRIPT_DIR}/config" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/config"
fi
if [[ -f "${HOME}/.codex_yolo/config" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.codex_yolo/config"
fi

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
REPO="${CODEX_YOLO_REPO:-laurenceputra/codex_yolo}"
BRANCH="${CODEX_YOLO_BRANCH:-main}"
VERBOSE="${CODEX_VERBOSE:-0}"
MOUNT_SSH=0

log_verbose() {
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

log_info() {
  echo "$*" >&2
}

log_error() {
  echo "Error: $*" >&2
}

# Handle special commands before Docker checks
if [[ "${#}" -gt 0 ]]; then
  case "${1}" in
    diagnostics|doctor|health)
      exec "${SCRIPT_DIR}/.codex_yolo_diagnostics.sh"
      ;;
    version)
      if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
        cat "${SCRIPT_DIR}/VERSION"
      else
        echo "unknown"
      fi
      exit 0
      ;;
    --version)
      if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
        echo "codex_yolo version $(cat "${SCRIPT_DIR}/VERSION")"
      else
        echo "codex_yolo version unknown"
      fi
      exit 0
      ;;
  esac
fi

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
  log_error "Docker is not installed or not on PATH"
  log_info "${install_hint}"
  log_info "Run 'codex_yolo diagnostics' for more troubleshooting help"
  exit 127
fi

if ! docker info >/dev/null 2>&1; then
  log_error "Docker is installed but the daemon is not running"
  log_info "Start Docker Desktop or the Docker Engine service, then try again"
  log_info "${install_hint}"
  log_info "Run 'codex_yolo diagnostics' for more troubleshooting help"
  exit 1
fi

# Check for updates unless explicitly disabled
if [[ "${CODEX_SKIP_UPDATE_CHECK:-0}" != "1" ]]; then
  local_version=""
  if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
    local_version="$(tr -d '\n ' < "${SCRIPT_DIR}/VERSION")"
  fi
  
  if command -v curl >/dev/null 2>&1; then
    remote_version="$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" 2>/dev/null | tr -d '\n ' || true)"
    
    if [[ -n "${remote_version}" && "${remote_version}" != "${local_version}" ]]; then
      log_info "codex_yolo update available: ${local_version:-unknown} -> ${remote_version}"
      log_info "Updating from ${REPO}/${BRANCH}..."
      log_verbose "Downloading update files..."
      
      temp_dir="$(mktemp -d)"
      trap 'rm -rf "${temp_dir}"' EXIT
      
      # Download core files (required)
      if curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo.sh" -o "${temp_dir}/.codex_yolo.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo.Dockerfile" -o "${temp_dir}/.codex_yolo.Dockerfile" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo_entrypoint.sh" -o "${temp_dir}/.codex_yolo_entrypoint.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo_diagnostics.sh" -o "${temp_dir}/.codex_yolo_diagnostics.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.dockerignore" -o "${temp_dir}/.dockerignore" 2>/dev/null && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" -o "${temp_dir}/VERSION"; then
        
        # Download optional files (don't fail if these are missing)
        for optional_file in ".codex_yolo_completion.bash" ".codex_yolo_completion.zsh" ".codex_yolo.conf.example" "EXAMPLES.md"; do
          curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/${optional_file}" -o "${temp_dir}/${optional_file}" 2>/dev/null || true
        done
        
        # Install core files
        chmod +x "${temp_dir}/.codex_yolo.sh"
        chmod +x "${temp_dir}/.codex_yolo_diagnostics.sh"
        cp "${temp_dir}/.codex_yolo.sh" "${SCRIPT_DIR}/.codex_yolo.sh"
        cp "${temp_dir}/.codex_yolo.Dockerfile" "${SCRIPT_DIR}/.codex_yolo.Dockerfile"
        cp "${temp_dir}/.codex_yolo_entrypoint.sh" "${SCRIPT_DIR}/.codex_yolo_entrypoint.sh"
        cp "${temp_dir}/.codex_yolo_diagnostics.sh" "${SCRIPT_DIR}/.codex_yolo_diagnostics.sh"
        cp "${temp_dir}/.dockerignore" "${SCRIPT_DIR}/.dockerignore" 2>/dev/null || true
        cp "${temp_dir}/VERSION" "${SCRIPT_DIR}/VERSION"
        
        # Install optional files if they were downloaded
        for optional_file in ".codex_yolo_completion.bash" ".codex_yolo_completion.zsh" ".codex_yolo.conf.example" "EXAMPLES.md"; do
          [[ -f "${temp_dir}/${optional_file}" ]] && cp "${temp_dir}/${optional_file}" "${SCRIPT_DIR}/${optional_file}" 2>/dev/null || true
        done
        
        log_info "Updated to version ${remote_version}"
        log_verbose "Updated files in ${SCRIPT_DIR}"
        log_info "Re-executing with new version..."
        exec "${SCRIPT_DIR}/.codex_yolo.sh" "$@"
      else
        log_info "Warning: failed to download updates; continuing with local version"
      fi
    fi
  fi
fi

if [[ "${CODEX_SKIP_VERSION_CHECK:-0}" != "1" ]] && ! docker buildx version >/dev/null 2>&1; then
  log_info "Warning: docker buildx is not available; builds may be slower or fail on some systems"
  log_info "Install Docker Buildx to improve build reliability: https://docs.docker.com/build/buildx/"
fi

pass_args=()
for arg in "$@"; do
  case "${arg}" in
    --pull)
      PULL_REQUESTED=1
      continue
      ;;
    --verbose|-v)
      VERBOSE=1
      continue
      ;;
    --mount-ssh)
      MOUNT_SSH=1
      continue
      ;;
  esac
  pass_args+=("${arg}")
done

log_verbose "Script directory: ${SCRIPT_DIR}"
log_verbose "Workspace: ${WORKSPACE}"
log_verbose "User: ${USER_NAME}:${GROUP_NAME} (${USER_ID}:${GROUP_ID})"
log_verbose "Container home: ${CONTAINER_HOME}"
log_verbose "Container workdir: ${CONTAINER_WORKDIR}"

if [[ "${CONTAINER_HOME}" != /* ]]; then
  log_error "CODEX_YOLO_HOME must be an absolute path inside the container"
  exit 1
fi

if [[ "${CONTAINER_WORKDIR}" != /* ]]; then
  log_error "CODEX_YOLO_WORKDIR must be an absolute path inside the container"
  exit 1
fi

if [[ "${IMAGE}" != "codex-cli-yolo:local" ]]; then
  log_info "Warning: CODEX_YOLO_IMAGE is set to a non-default image; use only images you trust"
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
  image_version="$(docker run --rm "${IMAGE}" cat /opt/codex-version 2>/dev/null | tr -d '\n' || true)"
fi

# Check if we need to build the image
# Build if: forced rebuild, forced pull, image missing, or version mismatch
version_mismatch=0
if [[ -n "${latest_version}" ]] && { [[ -z "${image_version}" ]] || [[ "${latest_version}" != "${image_version}" ]]; }; then
  version_mismatch=1
fi

need_build=0
if [[ "${CODEX_BUILD_NO_CACHE:-0}" == "1" ]] || \
   [[ "${CODEX_BUILD_PULL:-0}" == "1" ]] || \
   [[ "${PULL_REQUESTED}" == "1" ]] || \
   [[ "${image_exists}" == "0" ]] || \
   [[ "${version_mismatch}" == "1" ]]; then
  need_build=1
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

# Mount .ssh directory if explicitly enabled
if [[ "${MOUNT_SSH}" == "1" ]]; then
  if [[ -d "${HOME}/.ssh" ]]; then
    docker_args+=("-v" "${HOME}/.ssh:${CONTAINER_HOME}/.ssh:ro")
    log_info "⚠️  WARNING: SSH keys are now accessible inside the container."
    log_info "⚠️  Please ensure critical branches are protected in your repository settings."
    log_info "⚠️  Codex agents with --yolo mode can now push to remote repositories."
  else
    log_error "SSH mounting enabled but ${HOME}/.ssh does not exist or is not a directory."
    exit 1
  fi
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
  log_error "Unable to create ${HOME}/.codex on the host"
  exit 1
fi

if [[ ! -w "${HOME}/.codex" ]]; then
  log_error "${HOME}/.codex is not writable"
  log_info "Check permissions or set HOME to a writable directory"
  exit 1
fi

if [[ -z "${latest_version}" && "${image_exists}" == "1" && "${CODEX_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  log_info "Warning: could not check latest @openai/codex version; using existing image"
fi

if [[ "${need_build}" == "1" ]]; then
  if [[ -n "${latest_version}" && -n "${image_version}" && "${latest_version}" != "${image_version}" ]]; then
    log_info "Updating Codex CLI ${image_version} -> ${latest_version}"
  fi
  # Force BuildKit to avoid the legacy builder deprecation warning.
  DOCKER_BUILDKIT=1 docker build "${build_args[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${SCRIPT_DIR}"
fi

if [[ "${#pass_args[@]}" -gt 0 && "${pass_args[0]}" == "login" ]]; then
  docker run "${docker_args[@]}" "${IMAGE}" codex "${pass_args[@]}"
else
  docker run "${docker_args[@]}" "${IMAGE}" codex --yolo --search "${pass_args[@]}"
fi
