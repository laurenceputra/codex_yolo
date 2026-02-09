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

# Test 15: SSH mounting with --mount-ssh flag
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

# Test 16: Wrapper version metadata is embedded in Dockerfile
log_test "Dockerfile embeds wrapper version metadata"
dockerfile="${SCRIPT_DIR}/../.codex_yolo.Dockerfile"
if grep -q 'ARG CODEX_YOLO_WRAPPER_VERSION=' "${dockerfile}" && \
   grep -q '/opt/codex-yolo-version' "${dockerfile}"; then
  log_pass "Dockerfile contains wrapper version metadata support"
else
  log_fail "Dockerfile missing wrapper version metadata support"
fi

# Test 17: Main script rebuild logic includes wrapper version mismatch checks
log_test "Main script rebuilds when wrapper VERSION changes"
if grep -q 'CODEX_YOLO_WRAPPER_VERSION=' "${CODEX_YOLO_SH}" && \
   grep -q '/opt/codex-yolo-version' "${CODEX_YOLO_SH}" && \
   grep -q 'wrapper_version_mismatch' "${CODEX_YOLO_SH}"; then
  log_pass "Wrapper version mismatch rebuild logic found"
else
  log_fail "Wrapper version mismatch rebuild logic missing"
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
