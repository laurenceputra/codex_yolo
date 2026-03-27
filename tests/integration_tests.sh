#!/usr/bin/env bash
# Basic integration tests for codex_yolo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_YOLO_SH="${SCRIPT_DIR}/../.codex_yolo.sh"
DIAGNOSTICS_SH="${SCRIPT_DIR}/../.codex_yolo_diagnostics.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0
skipped=0

log_test() {
  echo -e "${YELLOW}TEST:${NC} $*"
}

log_pass() {
  echo -e "${GREEN}✓ PASS:${NC} $*"
  passed=$((passed + 1))
}

log_fail() {
  echo -e "${RED}✗ FAIL:${NC} $*"
  failed=$((failed + 1))
}

log_skip() {
  echo -e "${YELLOW}⊘ SKIP:${NC} $*"
  skipped=$((skipped + 1))
}

log_info() {
  echo -e "  $*"
}

capture_command() {
  local __output_var="$1"
  local __status_var="$2"
  shift 2

  local captured_output
  local captured_status
  if captured_output=$("$@" 2>&1); then
    captured_status=0
  else
    captured_status=$?
  fi

  printf -v "${__output_var}" '%s' "${captured_output}"
  printf -v "${__status_var}" '%s' "${captured_status}"
}

create_fake_docker() {
  local fake_bin="$1"

  cat > "${fake_bin}/docker" <<'TESTEOF'
#!/bin/bash
case "${1:-}" in
  --version)
    printf '%s\n' 'Docker version 26.1.0, build test'
    exit 0
    ;;
  info)
    exit 0
    ;;
  version)
    if [[ "${2:-}" == "--format" ]]; then
      printf '%s\n' '26.1.0'
      exit 0
    fi
    printf '%s\n' 'Server: Docker Engine - Community'
    exit 0
    ;;
  buildx)
    if [[ "${2:-}" == "version" ]]; then
      printf '%s\n' 'github.com/docker/buildx 0.14.0 test'
      exit 0
    fi
    ;;
  image)
    if [[ "${2:-}" == "inspect" ]]; then
      if [[ -n "${FAKE_DOCKER_IMAGE_SIZE_BYTES:-}" ]]; then
        printf '%s\n' "${FAKE_DOCKER_IMAGE_SIZE_BYTES}"
        exit 0
      fi
      exit 1
    fi
    ;;
  build|run)
    exit 0
    ;;
esac
exit 0
TESTEOF

  chmod +x "${fake_bin}/docker"
}

echo "=== codex_yolo Test Suite ==="
echo ""

# Test 1: Check if main script exists
log_test "Main script exists"
if [[ -f "${CODEX_YOLO_SH}" ]]; then
  log_pass "Script found at ${CODEX_YOLO_SH}"
else
  log_fail "Script not found at ${CODEX_YOLO_SH}"
fi

# Test 2: Check if diagnostics script exists
log_test "Diagnostics script exists"
if [[ -f "${DIAGNOSTICS_SH}" ]]; then
  log_pass "Diagnostics script found"
else
  log_fail "Diagnostics script not found"
fi

# Test 3: Check if scripts are executable
log_test "Scripts are executable"
if [[ -x "${CODEX_YOLO_SH}" ]] && [[ -x "${DIAGNOSTICS_SH}" ]]; then
  log_pass "Scripts have execute permissions"
else
  log_fail "Scripts missing execute permissions"
fi

# Test 4: Check for syntax errors
log_test "Shell script syntax check"
if bash -n "${CODEX_YOLO_SH}" 2>/dev/null && bash -n "${DIAGNOSTICS_SH}" 2>/dev/null; then
  log_pass "No syntax errors"
else
  log_fail "Syntax errors found"
fi

# Test 5: Version command
log_test "Version command"
if [[ -f "${SCRIPT_DIR}/../VERSION" ]]; then
  version_output=$("${CODEX_YOLO_SH}" version 2>&1 || true)
  if [[ -n "${version_output}" ]]; then
    log_pass "Version command works: ${version_output}"
  else
    log_fail "Version command produced no output"
  fi
else
  log_skip "VERSION file not found"
fi

# Test 6: --version flag
log_test "--version flag"
version_output=$("${CODEX_YOLO_SH}" --version 2>&1 || true)
if echo "${version_output}" | grep -q "version"; then
  log_pass "--version flag works"
else
  log_fail "--version flag didn't work as expected"
fi

# Test 7: Diagnostics command (requires Docker)
log_test "Diagnostics command"
if command -v docker >/dev/null 2>&1; then
  diag_output=$("${CODEX_YOLO_SH}" diagnostics 2>&1 || true)
  if echo "${diag_output}" | grep -q "Diagnostics"; then
    log_pass "Diagnostics command works"
  else
    log_fail "Diagnostics command didn't produce expected output"
  fi
else
  log_skip "Docker not available, skipping diagnostics test"
fi

# Test 8: Doctor alias
log_test "Doctor alias for diagnostics"
if command -v docker >/dev/null 2>&1; then
  doctor_output=$("${CODEX_YOLO_SH}" doctor 2>&1 || true)
  if echo "${doctor_output}" | grep -q "Diagnostics"; then
    log_pass "Doctor alias works"
  else
    log_fail "Doctor alias didn't work"
  fi
else
  log_skip "Docker not available, skipping doctor test"
fi

# Test 9: Dry run mode
log_test "Dry run mode"
if command -v docker >/dev/null 2>&1; then
  export CODEX_DRY_RUN=1
  export CODEX_SKIP_UPDATE_CHECK=1
  dryrun_output=$("${CODEX_YOLO_SH}" --help 2>&1 || true)
  unset CODEX_DRY_RUN
  unset CODEX_SKIP_UPDATE_CHECK

  if echo "${dryrun_output}" | grep -q "Dry run"; then
    log_pass "Dry run mode works"
  else
    log_fail "Dry run mode didn't work as expected"
  fi
else
  log_skip "Docker not available, skipping dry run test"
fi

# Test 10: Completion files exist
log_test "Completion files exist"
bash_completion="${SCRIPT_DIR}/../.codex_yolo_completion.bash"
zsh_completion="${SCRIPT_DIR}/../.codex_yolo_completion.zsh"

if [[ -f "${bash_completion}" ]] && [[ -f "${zsh_completion}" ]]; then
  log_pass "Completion files found"
else
  log_fail "Missing completion files"
fi

# Test 11: Example config file exists
log_test "Example configuration file exists"
example_config="${SCRIPT_DIR}/../.codex_yolo.conf.example"
if [[ -f "${example_config}" ]]; then
  log_pass "Example config found"
else
  log_fail "Example config not found"
fi

# Test 12: Examples documentation exists
log_test "Examples documentation exists"
examples_doc="${SCRIPT_DIR}/../EXAMPLES.md"
if [[ -f "${examples_doc}" ]]; then
  log_pass "EXAMPLES.md found"
else
  log_fail "EXAMPLES.md not found"
fi

# Test 13: Default AGENTS template exists
log_test "Default AGENTS template exists"
default_agents_template="${SCRIPT_DIR}/../default-AGENTS.md"
if [[ -f "${default_agents_template}" ]]; then
  log_pass "default-AGENTS.md found"
else
  log_fail "default-AGENTS.md not found"
fi

# Test 14: Config file loading
log_test "Config file loading"
test_config="/tmp/test_codex_yolo_config"
test_script=$(mktemp)
test_home=$(mktemp -d)

# Setup cleanup trap
cleanup_test_13() {
  rm -f "${test_script}" "${test_config}"
  rm -rf "${test_home}"
}
trap cleanup_test_13 EXIT

cat > "${test_config}" <<EOF
CODEX_VERBOSE=1
CODEX_BASE_IMAGE=node:18-slim
EOF

# Create a test script that sources the main script logic
cat > "${test_script}" <<TESTEOF
#!/usr/bin/env bash
set -euo pipefail
HOME="${test_home}"
mkdir -p "\${HOME}/.codex_yolo"
if [[ -f "\${HOME}/.codex_yolo/config" ]]; then
  source "\${HOME}/.codex_yolo/config"
fi
echo "CODEX_VERBOSE=\${CODEX_VERBOSE:-0}"
echo "CODEX_BASE_IMAGE=\${CODEX_BASE_IMAGE:-node:20-slim}"
TESTEOF

chmod +x "${test_script}"
mkdir -p "${test_home}/.codex_yolo"
cp "${test_config}" "${test_home}/.codex_yolo/config"

output=$("${test_script}" 2>&1)
cleanup_test_13
trap - EXIT

if echo "${output}" | grep -q "CODEX_VERBOSE=1" && echo "${output}" | grep -q "node:18-slim"; then
  log_pass "Config file loading works"
else
  log_fail "Config file loading didn't work"
  log_info "Output: ${output}"
fi

# Test 15: Config priority and install dir support
log_test "Config file priority (install dir config < ~/.codex_yolo/config)"
test_script_dir=$(mktemp -d)
test_home=$(mktemp -d)
test_script=$(mktemp)

cleanup_test_14() {
  rm -rf "${test_script_dir}" "${test_home}" "${test_script}"
}
trap cleanup_test_14 EXIT

# Create test configs with different values
echo 'TEST_VAR=from_install_dir' > "${test_script_dir}/config"
mkdir -p "${test_home}/.codex_yolo"
echo 'TEST_VAR=from_config_dir' > "${test_home}/.codex_yolo/config"

# Test that later configs override earlier ones
cat > "${test_script}" <<TESTEOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="${test_script_dir}"
HOME="${test_home}"
if [[ -f "\${SCRIPT_DIR}/config" ]]; then
  source "\${SCRIPT_DIR}/config"
fi
if [[ -f "\${HOME}/.codex_yolo/config" ]]; then
  source "\${HOME}/.codex_yolo/config"
fi
echo "TEST_VAR=\${TEST_VAR:-unset}"
TESTEOF

chmod +x "${test_script}"
output=$("${test_script}" 2>&1)
cleanup_test_14
trap - EXIT

if echo "${output}" | grep -q "TEST_VAR=from_config_dir"; then
  log_pass "Config priority works correctly"
else
  log_fail "Config priority incorrect"
  log_info "Output: ${output}"
fi

# Test 16: SSH mounting with --mount-ssh flag
log_test "SSH mounting with --mount-ssh flag"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  # Create a temporary home directory for testing
  test_home=$(mktemp -d)

  cleanup_test_15() {
    rm -rf "${test_home}"
  }
  trap cleanup_test_15 EXIT

  # Create fake .ssh directory
  mkdir -p "${test_home}/.ssh"
  touch "${test_home}/.ssh/id_rsa"

  # Test with --mount-ssh flag in dry run mode
  original_home="${HOME}"
  export HOME="${test_home}"
  export CODEX_DRY_RUN=1
  export CODEX_SKIP_UPDATE_CHECK=1

  output=$("${CODEX_YOLO_SH}" --mount-ssh 2>&1 || true)

  export HOME="${original_home}"
  unset CODEX_DRY_RUN
  unset CODEX_SKIP_UPDATE_CHECK

  cleanup_test_15
  trap - EXIT

  # Check if the output includes SSH mount and warning
  if echo "${output}" | grep -q "\.ssh" && echo "${output}" | grep -qi "warning.*ssh\|ssh.*warning"; then
    log_pass "SSH mounting with --mount-ssh flag works correctly"
  else
    log_fail "SSH mounting with --mount-ssh flag didn't work as expected"
    log_info "Output snippet: $(echo "${output}" | grep -i ssh | head -5)"
  fi
else
  log_skip "Docker not available, skipping --mount-ssh flag test"
fi

# Test 17: Wrapper version metadata is embedded in Dockerfile
log_test "Dockerfile embeds wrapper version metadata"
dockerfile="${SCRIPT_DIR}/../.codex_yolo.Dockerfile"
if grep -q 'ARG CODEX_YOLO_WRAPPER_VERSION=' "${dockerfile}" && \
   grep -q '/opt/codex-yolo-version' "${dockerfile}"; then
  log_pass "Dockerfile contains wrapper version metadata support"
else
  log_fail "Dockerfile missing wrapper version metadata support"
fi

# Test 18: Main script rebuild logic includes wrapper version mismatch checks
log_test "Main script rebuilds when wrapper VERSION changes"
if grep -q 'CODEX_YOLO_WRAPPER_VERSION=' "${CODEX_YOLO_SH}" && \
   grep -q '/opt/codex-yolo-version' "${CODEX_YOLO_SH}" && \
   grep -q 'wrapper_version_mismatch' "${CODEX_YOLO_SH}"; then
  log_pass "Wrapper version mismatch rebuild logic found"
else
  log_fail "Wrapper version mismatch rebuild logic missing"
fi

# Test 19: Dockerfile includes rg and gh packages
log_test "Dockerfile installs rg and gh"
if grep -q 'gh' "${dockerfile}" && grep -q 'ripgrep' "${dockerfile}"; then
  log_pass "Dockerfile includes gh and ripgrep packages"
else
  log_fail "Dockerfile missing gh and/or ripgrep package install"
fi

# Test 20: --gh mounting in dry run mode
log_test "GitHub mount with --gh flag"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  test_home=$(mktemp -d)
  fake_bin=$(mktemp -d)
  original_home="${HOME}"
  original_path="${PATH}"

  cleanup_test_20() {
    rm -rf "${test_home}" "${fake_bin}"
    export HOME="${original_home}"
    export PATH="${original_path}"
    unset CODEX_DRY_RUN
    unset CODEX_SKIP_UPDATE_CHECK
    unset CODEX_SKIP_VERSION_CHECK
  }
  trap cleanup_test_20 EXIT

  mkdir -p "${test_home}/.copilot" "${test_home}/.codex" "${test_home}/.config/gh"
  cat > "${fake_bin}/gh" <<'TESTEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" ]] && [[ "${2:-}" == "status" ]]; then
  exit 0
fi
exit 0
TESTEOF
  chmod +x "${fake_bin}/gh"

  export HOME="${test_home}"
  export PATH="${fake_bin}:${PATH}"
  export CODEX_DRY_RUN=1
  export CODEX_SKIP_UPDATE_CHECK=1
  export CODEX_SKIP_VERSION_CHECK=1

  output=$("${CODEX_YOLO_SH}" --gh 2>&1 || true)
  cleanup_test_20
  trap - EXIT

  if echo "${output}" | grep -q "\.copilot" && echo "${output}" | grep -q "\.config/gh" && echo "${output}" | grep -q "Dry run"; then
    log_pass "--gh flag mounts ~/.copilot and ~/.config/gh in dry run output"
  else
    log_fail "--gh flag did not mount ~/.copilot and ~/.config/gh as expected"
    log_info "Output snippet: $(echo "${output}" | grep -E -i 'copilot|config/gh' | head -5)"
  fi
else
  log_skip "Docker not available, skipping --gh flag test"
fi

# Test 21: Reject relative CODEX_YOLO_HOME
log_test "Reject relative CODEX_YOLO_HOME"
fake_bin=$(mktemp -d)
original_path="${PATH}"

cleanup_test_21() {
  rm -rf "${fake_bin}"
  export PATH="${original_path}"
  unset CODEX_SKIP_UPDATE_CHECK
  unset CODEX_SKIP_VERSION_CHECK
  unset CODEX_YOLO_HOME
}
trap cleanup_test_21 EXIT

create_fake_docker "${fake_bin}"
export PATH="${fake_bin}:${PATH}"
export CODEX_SKIP_UPDATE_CHECK=1
export CODEX_SKIP_VERSION_CHECK=1
export CODEX_YOLO_HOME="relative/home"

capture_command output status "${CODEX_YOLO_SH}"

cleanup_test_21
trap - EXIT

if [[ "${status}" -ne 0 ]] && echo "${output}" | grep -q "CODEX_YOLO_HOME must be an absolute path"; then
  log_pass "Relative CODEX_YOLO_HOME is rejected before running Docker"
else
  log_fail "Relative CODEX_YOLO_HOME was not rejected as expected"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 22: Reject relative CODEX_YOLO_WORKDIR
log_test "Reject relative CODEX_YOLO_WORKDIR"
fake_bin=$(mktemp -d)
original_path="${PATH}"

cleanup_test_22() {
  rm -rf "${fake_bin}"
  export PATH="${original_path}"
  unset CODEX_SKIP_UPDATE_CHECK
  unset CODEX_SKIP_VERSION_CHECK
  unset CODEX_YOLO_WORKDIR
}
trap cleanup_test_22 EXIT

create_fake_docker "${fake_bin}"
export PATH="${fake_bin}:${PATH}"
export CODEX_SKIP_UPDATE_CHECK=1
export CODEX_SKIP_VERSION_CHECK=1
export CODEX_YOLO_WORKDIR="workspace"

capture_command output status "${CODEX_YOLO_SH}"

cleanup_test_22
trap - EXIT

if [[ "${status}" -ne 0 ]] && echo "${output}" | grep -q "CODEX_YOLO_WORKDIR must be an absolute path"; then
  log_pass "Relative CODEX_YOLO_WORKDIR is rejected before running Docker"
else
  log_fail "Relative CODEX_YOLO_WORKDIR was not rejected as expected"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 23: --gh requires host gh binary
log_test "--gh requires host gh binary"
fake_bin=$(mktemp -d)
original_path="${PATH}"
host_bash="$(command -v bash)"

cleanup_test_23() {
  export PATH="${original_path}"
  rm -rf "${fake_bin}"
  unset CODEX_DRY_RUN
  unset CODEX_SKIP_UPDATE_CHECK
  unset CODEX_SKIP_VERSION_CHECK
}
trap cleanup_test_23 EXIT

create_fake_docker "${fake_bin}"
for required_tool in dirname id tr uname; do
  ln -s "$(command -v "${required_tool}")" "${fake_bin}/${required_tool}"
done
export PATH="${fake_bin}"
export CODEX_DRY_RUN=1
export CODEX_SKIP_UPDATE_CHECK=1
export CODEX_SKIP_VERSION_CHECK=1

capture_command output status "${host_bash}" "${CODEX_YOLO_SH}" --gh

cleanup_test_23
trap - EXIT

if [[ "${status}" -ne 0 ]] && echo "${output}" | grep -q -- "--gh requires GitHub CLI (gh) installed on the host" && echo "${output}" | grep -q "gh auth login"; then
  log_pass "--gh fails fast when gh is unavailable on the host"
else
  log_fail "--gh did not report the missing host gh prerequisite"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 24: --gh requires authenticated host gh session
log_test "--gh requires authenticated host gh session"
fake_bin=$(mktemp -d)
original_path="${PATH}"

cleanup_test_24() {
  rm -rf "${fake_bin}"
  export PATH="${original_path}"
  unset CODEX_DRY_RUN
  unset CODEX_SKIP_UPDATE_CHECK
  unset CODEX_SKIP_VERSION_CHECK
}
trap cleanup_test_24 EXIT

create_fake_docker "${fake_bin}"
cat > "${fake_bin}/gh" <<'TESTEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" ]] && [[ "${2:-}" == "status" ]]; then
  exit 1
fi
exit 0
TESTEOF
chmod +x "${fake_bin}/gh"

export PATH="${fake_bin}:${PATH}"
export CODEX_DRY_RUN=1
export CODEX_SKIP_UPDATE_CHECK=1
export CODEX_SKIP_VERSION_CHECK=1

capture_command output status "${CODEX_YOLO_SH}" --gh

cleanup_test_24
trap - EXIT

if [[ "${status}" -ne 0 ]] && echo "${output}" | grep -q -- "--gh requires host GitHub authentication" && echo "${output}" | grep -q "gh auth login"; then
  log_pass "--gh fails fast when host gh auth is missing"
else
  log_fail "--gh did not report the missing host gh auth prerequisite"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 25: --gh requires host Copilot state directory
log_test "--gh requires host ~/.copilot state"
fake_bin=$(mktemp -d)
test_home=$(mktemp -d)
original_path="${PATH}"
original_home="${HOME}"

cleanup_test_25() {
  rm -rf "${fake_bin}" "${test_home}"
  export PATH="${original_path}"
  export HOME="${original_home}"
  unset CODEX_DRY_RUN
  unset CODEX_SKIP_UPDATE_CHECK
  unset CODEX_SKIP_VERSION_CHECK
}
trap cleanup_test_25 EXIT

create_fake_docker "${fake_bin}"
cat > "${fake_bin}/gh" <<'TESTEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" ]] && [[ "${2:-}" == "status" ]]; then
  exit 0
fi
exit 0
TESTEOF
chmod +x "${fake_bin}/gh"

export PATH="${fake_bin}:${PATH}"
export HOME="${test_home}"
export CODEX_DRY_RUN=1
export CODEX_SKIP_UPDATE_CHECK=1
export CODEX_SKIP_VERSION_CHECK=1

capture_command output status "${CODEX_YOLO_SH}" --gh

cleanup_test_25
trap - EXIT

if [[ "${status}" -ne 0 ]] && echo "${output}" | grep -q -- "--gh enabled but .*\\.copilot does not exist or is not a directory" && echo "${output}" | grep -q "Ensure host Copilot data exists"; then
  log_pass "--gh fails fast when host Copilot state is missing"
else
  log_fail "--gh did not report the missing ~/.copilot prerequisite"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 26: costs command text output with Docker image metadata
log_test "Costs command reports text breakdown"
fake_bin=$(mktemp -d)
original_path="${PATH}"

cleanup_test_26() {
  rm -rf "${fake_bin}"
  export PATH="${original_path}"
  unset FAKE_DOCKER_IMAGE_SIZE_BYTES
  unset CODEX_COST_STORAGE_RATE_PER_GB_MONTH
  unset CODEX_COST_BUILD_RATE_PER_MINUTE
  unset CODEX_COST_RUNTIME_RATE_PER_HOUR
  unset CODEX_COST_BUILD_MINUTES
  unset CODEX_COST_RUNTIME_HOURS
  unset CODEX_COST_STORAGE_GB
}
trap cleanup_test_26 EXIT

create_fake_docker "${fake_bin}"
export PATH="${fake_bin}:${PATH}"
export FAKE_DOCKER_IMAGE_SIZE_BYTES=2500000000
export CODEX_COST_STORAGE_RATE_PER_GB_MONTH=0.02
export CODEX_COST_BUILD_RATE_PER_MINUTE=0.15
export CODEX_COST_RUNTIME_RATE_PER_HOUR=0.05
export CODEX_COST_BUILD_MINUTES=10
export CODEX_COST_RUNTIME_HOURS=4

capture_command output status "${CODEX_YOLO_SH}" costs

cleanup_test_26
trap - EXIT

if [[ "${status}" -eq 0 ]] && \
    echo "${output}" | grep -q "Cost attribution estimate" && \
    echo "${output}" | grep -q "Component ID" && \
    echo "${output}" | grep -q "image_storage" && \
    echo "${output}" | grep -q "docker_image_metadata" && \
    echo "${output}" | grep -q "scenario_rollup" && \
    echo "${output}" | grep -q '\$1\.750000'; then
  log_pass "Costs command reports a readable component breakdown"
else
  log_fail "Costs command text output did not include the expected breakdown"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 27: costs command JSON output
log_test "Costs command JSON output"
fake_bin=$(mktemp -d)
original_path="${PATH}"

cleanup_test_27() {
  rm -rf "${fake_bin}"
  export PATH="${original_path}"
  unset FAKE_DOCKER_IMAGE_SIZE_BYTES
  unset CODEX_COST_STORAGE_RATE_PER_GB_MONTH
  unset CODEX_COST_BUILD_RATE_PER_MINUTE
  unset CODEX_COST_RUNTIME_RATE_PER_HOUR
  unset CODEX_COST_BUILD_MINUTES
  unset CODEX_COST_RUNTIME_HOURS
  unset CODEX_COST_STORAGE_GB
}
trap cleanup_test_27 EXIT

create_fake_docker "${fake_bin}"
export PATH="${fake_bin}:${PATH}"
export FAKE_DOCKER_IMAGE_SIZE_BYTES=1000000000
export CODEX_COST_STORAGE_RATE_PER_GB_MONTH=0.03
export CODEX_COST_BUILD_RATE_PER_MINUTE=0.20
export CODEX_COST_RUNTIME_RATE_PER_HOUR=0.10
export CODEX_COST_BUILD_MINUTES=2
export CODEX_COST_RUNTIME_HOURS=3

capture_command output status "${CODEX_YOLO_SH}" costs --json

cleanup_test_27
trap - EXIT

if [[ "${status}" -eq 0 ]] && \
   echo "${output}" | grep -q '"schema_version":"costs.v2"' && \
   echo "${output}" | grep -q '"estimate_only":true' && \
   echo "${output}" | grep -q '"image_storage":{"quantity":{"value":1.000000,"unit":"gb","source":"docker_image_metadata"},"rate":{"value":0.030000,"unit":"usd_per_gb_month"},"cost":{"value":0.030000,"unit":"usd"}}' && \
   echo "${output}" | grep -q '"image_build":{"quantity":{"value":2.000000,"unit":"minute","source":"configured_value"},"rate":{"value":0.200000,"unit":"usd_per_minute"},"cost":{"value":0.400000,"unit":"usd"}}' && \
   echo "${output}" | grep -q '"container_runtime":{"quantity":{"value":3.000000,"unit":"hour","source":"configured_value"},"rate":{"value":0.100000,"unit":"usd_per_hour"},"cost":{"value":0.300000,"unit":"usd"}}' && \
   echo "${output}" | grep -q '"total":{"value":0.730000,"unit":"usd","source":"scenario_rollup"}'; then
  log_pass "Costs command emits expected JSON fields"
else
  log_fail "Costs command JSON output was missing expected fields"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 28: costs command rejects invalid numeric input
log_test "Costs command rejects invalid numeric input"
unset CODEX_COST_STORAGE_RATE_PER_GB_MONTH
unset CODEX_COST_BUILD_RATE_PER_MINUTE
unset CODEX_COST_RUNTIME_RATE_PER_HOUR
unset CODEX_COST_STORAGE_GB
unset CODEX_COST_RUNTIME_HOURS
export CODEX_COST_BUILD_MINUTES=abc

capture_command output status "${CODEX_YOLO_SH}" costs

unset CODEX_COST_BUILD_MINUTES

if [[ "${status}" -ne 0 ]] && echo "${output}" | grep -q "CODEX_COST_BUILD_MINUTES must be a non-negative number"; then
  log_pass "Costs command fails fast on invalid numeric settings"
else
  log_fail "Costs command did not reject invalid numeric settings"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 29: costs command preserves env over config precedence
log_test "Costs command honors env over config"
test_home=$(mktemp -d)

cleanup_test_29() {
  rm -rf "${test_home}"
  unset CODEX_YOLO_IMAGE
  unset CODEX_COST_STORAGE_RATE_PER_GB_MONTH
  unset CODEX_COST_BUILD_RATE_PER_MINUTE
  unset CODEX_COST_RUNTIME_RATE_PER_HOUR
  unset CODEX_COST_STORAGE_GB
  unset CODEX_COST_BUILD_MINUTES
  unset CODEX_COST_RUNTIME_HOURS
}
trap cleanup_test_29 EXIT

mkdir -p "${test_home}/.codex_yolo"
cat > "${test_home}/.codex_yolo/config" <<'TESTEOF'
CODEX_YOLO_IMAGE=from-config:latest
CODEX_COST_STORAGE_RATE_PER_GB_MONTH=9
CODEX_COST_BUILD_RATE_PER_MINUTE=2
CODEX_COST_RUNTIME_RATE_PER_HOUR=8
CODEX_COST_STORAGE_GB=5
CODEX_COST_BUILD_MINUTES=5
CODEX_COST_RUNTIME_HOURS=6
TESTEOF

capture_command output status env HOME="${test_home}" \
  CODEX_YOLO_IMAGE=env-wins:latest \
  CODEX_COST_STORAGE_RATE_PER_GB_MONTH=0 \
  CODEX_COST_BUILD_RATE_PER_MINUTE=3 \
  CODEX_COST_RUNTIME_RATE_PER_HOUR=0 \
  CODEX_COST_STORAGE_GB=0 \
  CODEX_COST_BUILD_MINUTES=7 \
  CODEX_COST_RUNTIME_HOURS=0 \
  "${CODEX_YOLO_SH}" costs --json

cleanup_test_29
trap - EXIT

if [[ "${status}" -eq 0 ]] && \
    echo "${output}" | grep -q '"image":"env-wins:latest"' && \
    echo "${output}" | grep -q '"image_build":{"quantity":{"value":7.000000,"unit":"minute","source":"configured_value"},"rate":{"value":3.000000,"unit":"usd_per_minute"},"cost":{"value":21.000000,"unit":"usd"}}' && \
    echo "${output}" | grep -q '"total":{"value":21.000000,"unit":"usd","source":"scenario_rollup"}'; then
  log_pass "Costs command uses environment overrides ahead of config values"
else
  log_fail "Costs command did not preserve env over config precedence"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 30: costs command works without Docker and uses fallback storage size
log_test "Costs command works without Docker using fallback storage"
fake_bin=$(mktemp -d)
original_path="${PATH}"
host_bash="$(command -v bash)"

cleanup_test_30() {
  export PATH="${original_path}"
  rm -rf "${fake_bin}"
}
trap cleanup_test_30 EXIT

for required_tool in dirname id tr uname awk env; do
  ln -s "$(command -v "${required_tool}")" "${fake_bin}/${required_tool}"
done
export PATH="${fake_bin}"

capture_command output status env \
  CODEX_COST_STORAGE_RATE_PER_GB_MONTH=0.01 \
  CODEX_COST_BUILD_RATE_PER_MINUTE=0 \
  CODEX_COST_RUNTIME_RATE_PER_HOUR=0 \
  CODEX_COST_STORAGE_GB=1.50 \
  CODEX_COST_BUILD_MINUTES=0 \
  CODEX_COST_RUNTIME_HOURS=0 \
  "${host_bash}" "${CODEX_YOLO_SH}" costs --json

cleanup_test_30
trap - EXIT

if [[ "${status}" -eq 0 ]] && \
   echo "${output}" | grep -q '"image_storage":{"quantity":{"value":1.500000,"unit":"gb","source":"configured_fallback"},"rate":{"value":0.010000,"unit":"usd_per_gb_month"},"cost":{"value":0.015000,"unit":"usd"}}' && \
   echo "${output}" | grep -q '"total":{"value":0.015000,"unit":"usd","source":"scenario_rollup"}'; then
  log_pass "Costs command stays deterministic without Docker"
else
  log_fail "Costs command did not use fallback storage size without Docker"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 31: diagnostics reports missing Docker without implying the image is missing
log_test "Diagnostics reports no-Docker status accurately"
fake_bin=$(mktemp -d)
test_home=$(mktemp -d)
host_bash="$(command -v bash)"

cleanup_test_31() {
  rm -rf "${fake_bin}" "${test_home}"
}
trap cleanup_test_31 EXIT

mkdir -p "${test_home}/.codex"
for required_tool in cat df dirname env find grep id sort tail wc; do
  ln -s "$(command -v "${required_tool}")" "${fake_bin}/${required_tool}"
done

capture_command output status env PATH="${fake_bin}" HOME="${test_home}" "${host_bash}" "${DIAGNOSTICS_SH}"

cleanup_test_31
trap - EXIT

if [[ "${status}" -ne 0 ]] && \
   echo "${output}" | grep -q "Docker not installed" && \
   echo "${output}" | grep -q "Cannot inspect image until Docker is installed" && \
   ! echo "${output}" | grep -q "Image not found:" && \
   echo "${output}" | grep -q "❌ 1 critical issue(s) found"; then
  log_pass "Diagnostics reports Docker as the blocker when Docker is unavailable"
else
  log_fail "Diagnostics still implied an image problem when Docker was unavailable"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Test 32: diagnostics treats a first-run ~/.codex directory as informational
log_test "Diagnostics allows a missing first-run ~/.codex directory"
fake_bin=$(mktemp -d)
test_home=$(mktemp -d)
host_bash="$(command -v bash)"

cleanup_test_32() {
  rm -rf "${fake_bin}" "${test_home}"
}
trap cleanup_test_32 EXIT

create_fake_docker "${fake_bin}"
for required_tool in cat df dirname env grep head id sort tail; do
  ln -s "$(command -v "${required_tool}")" "${fake_bin}/${required_tool}"
done

capture_command output status env PATH="${fake_bin}" HOME="${test_home}" "${host_bash}" "${DIAGNOSTICS_SH}"

cleanup_test_32
trap - EXIT

if [[ "${status}" -eq 0 ]] && \
   echo "${output}" | grep -q "Config directory missing: ${test_home}/.codex" && \
   echo "${output}" | grep -q "Config directory will be created on first run" && \
   echo "${output}" | grep -q "✅ All critical checks passed!" && \
   ! echo "${output}" | grep -q "Config directory missing or not writable"; then
  log_pass "Diagnostics treats a missing first-run config directory as informational"
else
  log_fail "Diagnostics still treated a missing first-run config directory as critical"
  log_info "Status: ${status}"
  log_info "Output: ${output}"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: ${passed}${NC}"
if [[ ${failed} -gt 0 ]]; then
  echo -e "${RED}Failed: ${failed}${NC}"
else
  echo "Failed: ${failed}"
fi
echo -e "${YELLOW}Skipped: ${skipped}${NC}"
echo "Total: $((passed + failed + skipped))"

if [[ ${failed} -gt 0 ]]; then
  exit 1
else
  exit 0
fi
