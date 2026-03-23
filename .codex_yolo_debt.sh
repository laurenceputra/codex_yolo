#!/usr/bin/env bash
set -euo pipefail

MARKER_REGEX='(^|[^[:alnum:]_])(TODO|FIXME|HACK|XXX)(\([^)]+\))?([[:space:]]*[:-]|[[:space:]]+)'

usage() {
  cat <<'USAGE'
Usage: codex_yolo debt [path]

Scan the current repository (or the optional path) for common technical-debt
markers, classify each finding with deterministic Bash heuristics, assign a
priority score, and print a prioritized report.

Scanned markers:
  TODO, FIXME, HACK, XXX

Categories:
  bug-risk            Potential correctness or stability issue
  maintainability     Cleanup or refactor debt in code
  test-gap            Missing or deferred test coverage work
  docs-config-infra   Documentation, configuration, or automation debt
USAGE
}

normalize_context() {
  printf '%s' "$1" | tr '\t' ' ' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g'
}

resolve_scan_root() {
  local requested_path="${1:-}"

  if [[ -n "${requested_path}" ]]; then
    if [[ ! -d "${requested_path}" ]]; then
      echo "Error: path not found: ${requested_path}" >&2
      exit 1
    fi

    (
      cd "${requested_path}"
      pwd
    )
    return
  fi

  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "${git_root}"
  else
    pwd
  fi
}

scan_matches() {
  find . \
    \( -path './.git' \
       -o -path './node_modules' \
       -o -path './dist' \
       -o -path './build' \
       -o -path './coverage' \
       -o -path './.next' \
       -o -path './.venv' \
       -o -path './venv' \
       -o -path './tmp' \
       -o -path './vendor' \
       -o -path './.turbo' \
       -o -path './.cache' \
    \) -prune -o -type f -print0 |
    while IFS= read -r -d '' file; do
      grep -nHI -E "${MARKER_REGEX}" "${file}" 2>/dev/null || true
    done
}

detect_marker() {
  local context="$1"
  local upper_context

  upper_context="$(printf '%s' "${context}" | tr '[:lower:]' '[:upper:]')"
  if [[ "${upper_context}" =~ ${MARKER_REGEX} ]]; then
    printf '%s\n' "${BASH_REMATCH[2]}"
  else
    printf 'TODO\n'
  fi
}

classify_category() {
  local marker="$1"
  local file_path="$2"
  local context="$3"
  local lower_path lower_context

  lower_path="$(printf '%s' "${file_path}" | tr '[:upper:]' '[:lower:]')"
  lower_context="$(printf '%s' "${context}" | tr '[:upper:]' '[:lower:]')"

  if [[ "${lower_path}" == *test* ]] || [[ "${lower_path}" == *spec* ]] ||
     [[ "${lower_context}" == *test* ]] || [[ "${lower_context}" == *coverage* ]] ||
     [[ "${lower_context}" == *regression* ]] || [[ "${lower_context}" == *fixture* ]] ||
     [[ "${lower_context}" == *assert* ]] || [[ "${lower_context}" == *flaky* ]]; then
    printf 'test-gap\n'
    return
  fi

  if [[ "${lower_path}" == *.md ]] || [[ "${lower_path}" == *.yml ]] || [[ "${lower_path}" == *.yaml ]] ||
     [[ "${lower_path}" == *dockerfile* ]] || [[ "${lower_path}" == *config* ]] ||
     [[ "${lower_path}" == *install.sh ]] || [[ "${lower_path}" == .github/workflows/* ]] ||
     [[ "${lower_context}" == *docs* ]] || [[ "${lower_context}" == *readme* ]] ||
     [[ "${lower_context}" == *workflow* ]] || [[ "${lower_context}" == *deploy* ]] ||
     [[ "${lower_context}" == *config* ]] || [[ "${lower_context}" == *ci* ]]; then
    printf 'docs-config-infra\n'
    return
  fi

  if [[ "${marker}" == "FIXME" ]] || [[ "${marker}" == "XXX" ]] ||
     [[ "${lower_context}" == *bug* ]] || [[ "${lower_context}" == *broken* ]] ||
     [[ "${lower_context}" == *error* ]] || [[ "${lower_context}" == *failure* ]] ||
     [[ "${lower_context}" == *failing* ]] || [[ "${lower_context}" == *crash* ]] ||
     [[ "${lower_context}" == *panic* ]] || [[ "${lower_context}" == *null* ]] ||
     [[ "${lower_context}" == *nil* ]] || [[ "${lower_context}" == *race* ]] ||
     [[ "${lower_context}" == *unsafe* ]]; then
    printf 'bug-risk\n'
    return
  fi

  printf 'maintainability\n'
}

calculate_score() {
  local marker="$1"
  local category="$2"
  local file_path="$3"
  local context="$4"
  local score=0
  local lower_path lower_context
  local severity_regex='critical|urgent|security|vuln|crash|panic|corrupt|deadlock|prod|production|data[[:space:]]loss'
  local signal_regex='bug|broken|error|failure|failing|regression|workaround|temporary|refactor|cleanup|remove|leak|unsafe|null|nil|timeout|retry'

  case "${marker}" in
    FIXME) score=70 ;;
    XXX) score=65 ;;
    HACK) score=55 ;;
    TODO) score=45 ;;
  esac

  case "${category}" in
    bug-risk) score=$((score + 20)) ;;
    test-gap) score=$((score + 15)) ;;
    docs-config-infra) score=$((score + 10)) ;;
    maintainability) score=$((score + 5)) ;;
  esac

  lower_path="$(printf '%s' "${file_path}" | tr '[:upper:]' '[:lower:]')"
  lower_context="$(printf '%s' "${context}" | tr '[:upper:]' '[:lower:]')"

  if [[ "${lower_context}" =~ ${severity_regex} ]]; then
    score=$((score + 15))
  fi

  if [[ "${lower_context}" =~ ${signal_regex} ]]; then
    score=$((score + 8))
  fi

  if [[ "${lower_path}" == src/* ]] || [[ "${lower_path}" == lib/* ]] ||
     [[ "${lower_path}" == app/* ]] || [[ "${lower_path}" == cmd/* ]] ||
     [[ "${lower_path}" == bin/* ]] || [[ "${lower_path}" == .github/workflows/* ]] ||
     [[ "${lower_path}" == .codex_yolo.sh ]] || [[ "${lower_path}" == .codex_yolo_entrypoint.sh ]] ||
     [[ "${lower_path}" == install.sh ]]; then
    score=$((score + 5))
  fi

  if (( score > 100 )); then
    score=100
  fi

  printf '%s\n' "${score}"
}

priority_label() {
  local score="$1"

  if (( score >= 85 )); then
    printf 'critical\n'
  elif (( score >= 70 )); then
    printf 'high\n'
  elif (( score >= 55 )); then
    printf 'medium\n'
  else
    printf 'low\n'
  fi
}

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 1 ]]; then
  echo "Error: expected zero or one path argument" >&2
  echo >&2
  usage >&2
  exit 1
fi

scan_root="$(resolve_scan_root "${1:-}")"
findings_file="$(mktemp)"
sorted_file="$(mktemp)"
trap 'rm -f "${findings_file}" "${sorted_file}"' EXIT

(
  cd "${scan_root}"
  scan_matches
) | while IFS= read -r match; do
  file_path="${match%%:*}"
  remainder="${match#*:}"
  line_number="${remainder%%:*}"
  context="${remainder#*:}"
  file_path="${file_path#./}"
  context="$(normalize_context "${context}")"
  marker="$(detect_marker "${context}")"
  category="$(classify_category "${marker}" "${file_path}" "${context}")"
  score="$(calculate_score "${marker}" "${category}" "${file_path}" "${context}")"
  priority="$(priority_label "${score}")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${score}" "${priority}" "${category}" "${marker}" "${file_path}" "${line_number}" "${context}" >> "${findings_file}"
done

if [[ ! -s "${findings_file}" ]]; then
  echo "No technical debt markers found in ${scan_root}."
  exit 0
fi

LC_ALL=C sort -t $'\t' -k1,1nr -k5,5 -k6,6n "${findings_file}" > "${sorted_file}"

total_findings="$(wc -l < "${sorted_file}" | tr -d ' ')"

echo "codex_yolo debt report"
echo "Scope: ${scan_root}"
echo "Findings: ${total_findings}"
echo "Markers: TODO, FIXME, HACK, XXX"
echo "Priority score: marker severity + category + risk keywords"
echo ""
printf '%-9s %-5s %-20s %-7s %-28s %s\n' "Priority" "Score" "Category" "Marker" "Location" "Context"
printf '%-9s %-5s %-20s %-7s %-28s %s\n' "--------" "-----" "--------" "------" "--------" "-------"

while IFS=$'\t' read -r score priority category marker file_path line_number context; do
  printf '%-9s %-5s %-20s %-7s %-28s %s\n' \
    "${priority}" "${score}" "${category}" "${marker}" "${file_path}:${line_number}" "${context}"
done < "${sorted_file}"

echo ""
echo "Category counts:"
for category in bug-risk maintainability test-gap docs-config-infra; do
  count="$(awk -F '\t' -v wanted="${category}" '$3 == wanted { total += 1 } END { print total + 0 }' "${sorted_file}")"
  if [[ "${count}" != "0" ]]; then
    echo "  ${category}: ${count}"
  fi
done
