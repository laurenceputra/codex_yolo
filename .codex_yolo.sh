#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Preserve environment overrides so config files stay lower precedence.
CONFIG_OVERRIDE_VARS=(
  CODEX_BASE_IMAGE
  CODEX_YOLO_IMAGE
  CODEX_YOLO_HOME
  CODEX_YOLO_WORKDIR
  CODEX_YOLO_CLEANUP
  CODEX_YOLO_REPO
  CODEX_YOLO_BRANCH
  CODEX_SKIP_UPDATE_CHECK
  CODEX_SKIP_VERSION_CHECK
  CODEX_BUILD_NO_CACHE
  CODEX_BUILD_PULL
  CODEX_DRY_RUN
  CODEX_VERBOSE
  CODEX_COST_STORAGE_RATE_PER_GB_MONTH
  CODEX_COST_BUILD_RATE_PER_MINUTE
  CODEX_COST_RUNTIME_RATE_PER_HOUR
  CODEX_COST_STORAGE_GB
  CODEX_COST_BUILD_MINUTES
  CODEX_COST_RUNTIME_HOURS
)
for config_var in "${CONFIG_OVERRIDE_VARS[@]}"; do
  backup_var="__CODEX_ENV_OVERRIDE_${config_var}"
  if [[ "${!config_var+x}" == "x" ]]; then
    printf -v "${backup_var}" '%s' "${!config_var}"
  else
    printf -v "${backup_var}" '%s' "__CODEX_YOLO_UNSET__"
  fi
done

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
for config_var in "${CONFIG_OVERRIDE_VARS[@]}"; do
  backup_var="__CODEX_ENV_OVERRIDE_${config_var}"
  if [[ "${!backup_var}" != "__CODEX_YOLO_UNSET__" ]]; then
    printf -v "${config_var}" '%s' "${!backup_var}"
    export "${config_var}"
  fi
done

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
MOUNT_GH=0
WRAPPER_VERSION="unknown"
if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
  WRAPPER_VERSION="$(tr -d '\n ' < "${SCRIPT_DIR}/VERSION")"
fi

COSTS_SCHEMA_VERSION="costs.v2"
COSTS_CURRENCY_UNIT="usd"
COSTS_COMPONENT_IMAGE_STORAGE="image_storage"
COSTS_COMPONENT_IMAGE_BUILD="image_build"
COSTS_COMPONENT_CONTAINER_RUNTIME="container_runtime"
COSTS_SOURCE_DOCKER_IMAGE_METADATA="docker_image_metadata"
COSTS_SOURCE_CLI_OVERRIDE="cli_override"
COSTS_SOURCE_CONFIGURED_VALUE="configured_value"
COSTS_SOURCE_CONFIGURED_FALLBACK="configured_fallback"
COSTS_SOURCE_DEFAULT_VALUE="default_value"
COSTS_SOURCE_SCENARIO_ROLLUP="scenario_rollup"
COSTS_QUANTITY_UNIT_STORAGE="gb"
COSTS_QUANTITY_UNIT_BUILD="minute"
COSTS_QUANTITY_UNIT_RUNTIME="hour"
COSTS_RATE_UNIT_STORAGE="usd_per_gb_month"
COSTS_RATE_UNIT_BUILD="usd_per_minute"
COSTS_RATE_UNIT_RUNTIME="usd_per_hour"

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

show_costs_help() {
  cat <<EOF
Usage: codex_yolo costs [--json] [--image IMAGE] [--storage-gb GB] [--build-minutes MINUTES] [--runtime-hours HOURS]

Estimate per-component costs for:
  - image_storage     (one month of local image storage)
  - image_build       (one image build duration)
  - container_runtime (one runtime window)

This command is a host-side estimate only. It uses CODEX_COST_* values plus
local Docker image metadata when available. It does not query live billing APIs.

The JSON output uses schema_version '${COSTS_SCHEMA_VERSION}' with canonical
component IDs, source labels, and nested quantity/rate/cost objects.

Configuration:
  CODEX_COST_STORAGE_RATE_PER_GB_MONTH
  CODEX_COST_BUILD_RATE_PER_MINUTE
  CODEX_COST_RUNTIME_RATE_PER_HOUR
  CODEX_COST_STORAGE_GB
  CODEX_COST_BUILD_MINUTES
  CODEX_COST_RUNTIME_HOURS

Flags:
  --json               Emit machine-readable JSON
  --image IMAGE        Inspect a different local Docker image
  --storage-gb GB      Override image size when Docker metadata is unavailable
  --build-minutes N    Override build duration
  --runtime-hours N    Override runtime duration
  --help               Show this help text
EOF
}

require_cost_flag_value() {
  local flag_name="$1"
  local flag_value="${2:-}"

  if [[ -z "${flag_value}" || "${flag_value}" == --* ]]; then
    log_error "${flag_name} requires a value"
    exit 1
  fi
}

validate_cost_number() {
  local setting_name="$1"
  local setting_value="$2"

  if [[ ! "${setting_value}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    log_error "${setting_name} must be a non-negative number, got '${setting_value}'"
    exit 1
  fi
}

normalize_cost_number() {
  awk -v value="$1" 'BEGIN { printf "%.6f", value + 0 }'
}

multiply_cost_numbers() {
  awk -v left="$1" -v right="$2" 'BEGIN { printf "%.6f", left * right }'
}

bytes_to_cost_gb() {
  awk -v value="$1" 'BEGIN { printf "%.6f", value / 1000000000 }'
}

json_escape() {
  local escaped="${1//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//$'\n'/\\n}"
  escaped="${escaped//$'\r'/\\r}"
  escaped="${escaped//$'\t'/\\t}"
  printf '%s' "${escaped}"
}

emit_cost_component_json() {
  local component_id="$1"
  local quantity_value="$2"
  local quantity_unit="$3"
  local quantity_source="$4"
  local rate_value="$5"
  local rate_unit="$6"
  local component_cost="$7"

  printf '"%s":{"quantity":{"value":%s,"unit":"%s","source":"%s"},"rate":{"value":%s,"unit":"%s"},"cost":{"value":%s,"unit":"%s"}}' \
    "$(json_escape "${component_id}")" \
    "${quantity_value}" \
    "$(json_escape "${quantity_unit}")" \
    "$(json_escape "${quantity_source}")" \
    "${rate_value}" \
    "$(json_escape "${rate_unit}")" \
    "${component_cost}" \
    "$(json_escape "${COSTS_CURRENCY_UNIT}")"
}

emit_cost_component_row() {
  local component_id="$1"
  local quantity_display="$2"
  local rate_display="$3"
  local component_cost="$4"
  local quantity_source="$5"

  printf '%-20s %-18s %-24s %-14s %s\n' \
    "${component_id}" \
    "${quantity_display}" \
    "${rate_display}" \
    "\$${component_cost}" \
    "${quantity_source}"
}

run_costs_command() {
  local json_mode=0
  local image_name="${IMAGE}"
  local cli_storage_gb=""
  local cli_build_minutes=""
  local cli_runtime_hours=""

  shift
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json)
        json_mode=1
        ;;
      --image)
        require_cost_flag_value "$1" "${2:-}"
        image_name="$2"
        shift
        ;;
      --storage-gb)
        require_cost_flag_value "$1" "${2:-}"
        cli_storage_gb="$2"
        shift
        ;;
      --build-minutes)
        require_cost_flag_value "$1" "${2:-}"
        cli_build_minutes="$2"
        shift
        ;;
      --runtime-hours)
        require_cost_flag_value "$1" "${2:-}"
        cli_runtime_hours="$2"
        shift
        ;;
      --help|-h)
        show_costs_help
        exit 0
        ;;
      *)
        log_error "Unknown costs option: $1"
        log_info "Run 'codex_yolo costs --help' for usage"
        exit 1
        ;;
    esac
    shift
  done

  local storage_rate="${CODEX_COST_STORAGE_RATE_PER_GB_MONTH:-0}"
  local build_rate="${CODEX_COST_BUILD_RATE_PER_MINUTE:-0}"
  local runtime_rate="${CODEX_COST_RUNTIME_RATE_PER_HOUR:-0}"
  local build_minutes="${CODEX_COST_BUILD_MINUTES:-0}"
  local runtime_hours="${CODEX_COST_RUNTIME_HOURS:-0}"
  local configured_storage_gb="${CODEX_COST_STORAGE_GB:-}"

  if [[ -n "${cli_storage_gb}" ]]; then
    configured_storage_gb="${cli_storage_gb}"
  fi
  if [[ -n "${cli_build_minutes}" ]]; then
    build_minutes="${cli_build_minutes}"
  fi
  if [[ -n "${cli_runtime_hours}" ]]; then
    runtime_hours="${cli_runtime_hours}"
  fi

  validate_cost_number "CODEX_COST_STORAGE_RATE_PER_GB_MONTH" "${storage_rate}"
  validate_cost_number "CODEX_COST_BUILD_RATE_PER_MINUTE" "${build_rate}"
  validate_cost_number "CODEX_COST_RUNTIME_RATE_PER_HOUR" "${runtime_rate}"
  validate_cost_number "CODEX_COST_BUILD_MINUTES" "${build_minutes}"
  validate_cost_number "CODEX_COST_RUNTIME_HOURS" "${runtime_hours}"
  if [[ -n "${configured_storage_gb}" ]]; then
    validate_cost_number "CODEX_COST_STORAGE_GB" "${configured_storage_gb}"
  fi

  local storage_gb=""
  local storage_quantity_source=""
  local build_quantity_source="${COSTS_SOURCE_CONFIGURED_VALUE}"
  local runtime_quantity_source="${COSTS_SOURCE_CONFIGURED_VALUE}"
  local docker_size_bytes=""
  local storage_notes=()

  if [[ -n "${cli_build_minutes}" ]]; then
    build_quantity_source="${COSTS_SOURCE_CLI_OVERRIDE}"
  fi
  if [[ -n "${cli_runtime_hours}" ]]; then
    runtime_quantity_source="${COSTS_SOURCE_CLI_OVERRIDE}"
  fi

  if command -v docker >/dev/null 2>&1; then
    docker_size_bytes="$(docker image inspect --format '{{.Size}}' "${image_name}" 2>/dev/null || true)"
  fi

  if [[ "${docker_size_bytes}" =~ ^[0-9]+$ ]]; then
    storage_gb="$(bytes_to_cost_gb "${docker_size_bytes}")"
    storage_quantity_source="${COSTS_SOURCE_DOCKER_IMAGE_METADATA}"
  elif [[ -n "${configured_storage_gb}" ]]; then
    storage_gb="$(normalize_cost_number "${configured_storage_gb}")"
    if [[ -n "${cli_storage_gb}" ]]; then
      storage_quantity_source="${COSTS_SOURCE_CLI_OVERRIDE}"
    else
      storage_quantity_source="${COSTS_SOURCE_CONFIGURED_FALLBACK}"
    fi
    storage_notes+=("Docker image metadata was unavailable for '${image_name}', so storage used the configured fallback size.")
  else
    storage_gb="0.000000"
    storage_quantity_source="${COSTS_SOURCE_DEFAULT_VALUE}"
    storage_notes+=("Docker image metadata was unavailable for '${image_name}', so storage defaulted to 0. Set CODEX_COST_STORAGE_GB or use --storage-gb to override it.")
  fi

  local normalized_storage_rate
  local normalized_build_rate
  local normalized_runtime_rate
  local normalized_build_minutes
  local normalized_runtime_hours
  normalized_storage_rate="$(normalize_cost_number "${storage_rate}")"
  normalized_build_rate="$(normalize_cost_number "${build_rate}")"
  normalized_runtime_rate="$(normalize_cost_number "${runtime_rate}")"
  normalized_build_minutes="$(normalize_cost_number "${build_minutes}")"
  normalized_runtime_hours="$(normalize_cost_number "${runtime_hours}")"

  local image_storage_cost
  local image_build_cost
  local container_runtime_cost
  local total_cost
  image_storage_cost="$(multiply_cost_numbers "${storage_gb}" "${normalized_storage_rate}")"
  image_build_cost="$(multiply_cost_numbers "${normalized_build_minutes}" "${normalized_build_rate}")"
  container_runtime_cost="$(multiply_cost_numbers "${normalized_runtime_hours}" "${normalized_runtime_rate}")"
  total_cost="$(awk -v storage="${image_storage_cost}" -v build="${image_build_cost}" -v runtime="${container_runtime_cost}" 'BEGIN { printf "%.6f", storage + build + runtime }')"

  local estimate_notes=(
    "Estimate only. Uses configured CODEX_COST_* inputs and optional local Docker metadata; it does not query live billing data."
    "The total combines one month of image storage, one image build, and one runtime window."
  )
  if [[ "${#storage_notes[@]}" -gt 0 ]]; then
    estimate_notes+=("${storage_notes[@]}")
  fi

  if [[ "${json_mode}" == "1" ]]; then
    printf '{'
    printf '"schema_version":"%s",' "$(json_escape "${COSTS_SCHEMA_VERSION}")"
    printf '"estimate_only":true,'
    printf '"image":"%s",' "$(json_escape "${image_name}")"
    printf '"currency":"%s",' "$(json_escape "${COSTS_CURRENCY_UNIT}")"
    printf '"components":{'
    emit_cost_component_json \
      "${COSTS_COMPONENT_IMAGE_STORAGE}" \
      "${storage_gb}" \
      "${COSTS_QUANTITY_UNIT_STORAGE}" \
      "${storage_quantity_source}" \
      "${normalized_storage_rate}" \
      "${COSTS_RATE_UNIT_STORAGE}" \
      "${image_storage_cost}"
    printf ','
    emit_cost_component_json \
      "${COSTS_COMPONENT_IMAGE_BUILD}" \
      "${normalized_build_minutes}" \
      "${COSTS_QUANTITY_UNIT_BUILD}" \
      "${build_quantity_source}" \
      "${normalized_build_rate}" \
      "${COSTS_RATE_UNIT_BUILD}" \
      "${image_build_cost}"
    printf ','
    emit_cost_component_json \
      "${COSTS_COMPONENT_CONTAINER_RUNTIME}" \
      "${normalized_runtime_hours}" \
      "${COSTS_QUANTITY_UNIT_RUNTIME}" \
      "${runtime_quantity_source}" \
      "${normalized_runtime_rate}" \
      "${COSTS_RATE_UNIT_RUNTIME}" \
      "${container_runtime_cost}"
    printf '},'
    printf '"total":{"value":%s,"unit":"%s","source":"%s"},' \
      "${total_cost}" \
      "$(json_escape "${COSTS_CURRENCY_UNIT}")" \
      "$(json_escape "${COSTS_SOURCE_SCENARIO_ROLLUP}")"
    printf '"notes":['
    for note_index in "${!estimate_notes[@]}"; do
      if [[ "${note_index}" -gt 0 ]]; then
        printf ','
      fi
      printf '"%s"' "$(json_escape "${estimate_notes[${note_index}]}")"
    done
    printf ']'
    printf '}\n'
    exit 0
  fi

  echo "Cost attribution estimate for image '${image_name}'"
  echo "Estimate only: uses configured CODEX_COST_* inputs and optional local Docker metadata."
  echo "This is not live billing data."
  echo ""
  printf '%-20s %-18s %-24s %-14s %s\n' "Component ID" "Quantity" "Rate" "Estimate" "Input source"
  printf '%-20s %-18s %-24s %-14s %s\n' "--------------------" "------------------" "------------------------" "--------------" "---------------------"
  emit_cost_component_row "${COSTS_COMPONENT_IMAGE_STORAGE}" "${storage_gb} GB" "\$${normalized_storage_rate}/GB-month" "${image_storage_cost}" "${storage_quantity_source}"
  emit_cost_component_row "${COSTS_COMPONENT_IMAGE_BUILD}" "${normalized_build_minutes} min" "\$${normalized_build_rate}/min" "${image_build_cost}" "${build_quantity_source}"
  emit_cost_component_row "${COSTS_COMPONENT_CONTAINER_RUNTIME}" "${normalized_runtime_hours} hr" "\$${normalized_runtime_rate}/hr" "${container_runtime_cost}" "${runtime_quantity_source}"
  emit_cost_component_row "total" "" "" "${total_cost}" "${COSTS_SOURCE_SCENARIO_ROLLUP}"

  if [[ "${#estimate_notes[@]}" -gt 0 ]]; then
    echo ""
    echo "Notes:"
    for note in "${estimate_notes[@]}"; do
      echo "- ${note}"
    done
  fi

  exit 0
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
    costs)
      run_costs_command "$@"
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
  if command -v curl >/dev/null 2>&1; then
    remote_version="$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" 2>/dev/null | tr -d '\n ' || true)"

    if [[ -n "${remote_version}" && "${remote_version}" != "${WRAPPER_VERSION}" ]]; then
      log_info "codex_yolo update available: ${WRAPPER_VERSION} -> ${remote_version}"
      log_info "Updating from ${REPO}/${BRANCH}..."
      log_verbose "Downloading update files..."

      temp_dir="$(mktemp -d)"
      trap 'rm -rf "${temp_dir}"' EXIT

      # Download core files (required)
      if curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo.sh" -o "${temp_dir}/.codex_yolo.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo.Dockerfile" -o "${temp_dir}/.codex_yolo.Dockerfile" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo_entrypoint.sh" -o "${temp_dir}/.codex_yolo_entrypoint.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.codex_yolo_diagnostics.sh" -o "${temp_dir}/.codex_yolo_diagnostics.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/default-AGENTS.md" -o "${temp_dir}/default-AGENTS.md" && \
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
        cp "${temp_dir}/default-AGENTS.md" "${SCRIPT_DIR}/default-AGENTS.md"
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
    --gh)
      MOUNT_GH=1
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
build_args+=(--build-arg "CODEX_YOLO_WRAPPER_VERSION=${WRAPPER_VERSION}")
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
image_wrapper_version=""
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  image_exists=1
  image_version="$(docker run --rm "${IMAGE}" cat /opt/codex-version 2>/dev/null || true)"
  image_version="$(printf '%s' "${image_version}" | tr -d '\n')"
  image_wrapper_version="$(docker run --rm "${IMAGE}" cat /opt/codex-yolo-version 2>/dev/null || true)"
  image_wrapper_version="$(printf '%s' "${image_wrapper_version}" | tr -d '\n')"
fi

# Check if we need to build the image
# Build if: forced rebuild, forced pull, image missing, CLI version mismatch,
# or wrapper version mismatch.
version_mismatch=0
if [[ -n "${latest_version}" ]] && { [[ -z "${image_version}" ]] || [[ "${latest_version}" != "${image_version}" ]]; }; then
  version_mismatch=1
fi

wrapper_version_mismatch=0
if [[ "${image_exists}" == "1" ]] && [[ "${image_wrapper_version}" != "${WRAPPER_VERSION}" ]]; then
  wrapper_version_mismatch=1
fi

need_build=0
if [[ "${CODEX_BUILD_NO_CACHE:-0}" == "1" ]] || \
   [[ "${CODEX_BUILD_PULL:-0}" == "1" ]] || \
   [[ "${PULL_REQUESTED}" == "1" ]] || \
   [[ "${image_exists}" == "0" ]] || \
   [[ "${version_mismatch}" == "1" ]] || \
   [[ "${wrapper_version_mismatch}" == "1" ]]; then
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

# Mount .copilot directory if explicitly enabled for GitHub CLI workflows.
if [[ "${MOUNT_GH}" == "1" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    log_error "--gh requires GitHub CLI (gh) installed on the host."
    log_info "Install gh, authenticate on host, and retry: gh auth login"
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    log_error "--gh requires host GitHub authentication."
    log_info "Run on host first: gh auth login"
    exit 1
  fi

  if [[ -d "${HOME}/.copilot" ]]; then
    docker_args+=("-v" "${HOME}/.copilot:${CONTAINER_HOME}/.copilot")
    log_info "Warning: ${HOME}/.copilot is now mounted inside the container."
    if [[ -d "${HOME}/.config/gh" ]]; then
      docker_args+=("-v" "${HOME}/.config/gh:${CONTAINER_HOME}/.config/gh")
      log_info "Warning: ${HOME}/.config/gh is now mounted inside the container."
    else
      log_info "Warning: ${HOME}/.config/gh does not exist on the host; gh auth state may be unavailable inside the container."
    fi
    log_info "This enables gh workflows and GitHub Copilot-related host context access."
  else
    log_error "--gh enabled but ${HOME}/.copilot does not exist or is not a directory."
    log_info "Ensure host Copilot data exists after logging in with gh, then retry."
    exit 1
  fi
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
  if [[ "${wrapper_version_mismatch}" == "1" ]]; then
    if [[ -n "${image_wrapper_version}" ]]; then
      log_info "Updating codex_yolo wrapper ${image_wrapper_version} -> ${WRAPPER_VERSION}"
    else
      log_info "Rebuilding image to add codex_yolo wrapper metadata (${WRAPPER_VERSION})"
    fi
  fi
  # Force BuildKit to avoid the legacy builder deprecation warning.
  DOCKER_BUILDKIT=1 docker build "${build_args[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${SCRIPT_DIR}"
fi

if [[ "${#pass_args[@]}" -gt 0 && "${pass_args[0]}" == "login" ]]; then
  docker run "${docker_args[@]}" "${IMAGE}" codex "${pass_args[@]}"
else
  docker run "${docker_args[@]}" "${IMAGE}" codex --yolo --search "${pass_args[@]}"
fi
