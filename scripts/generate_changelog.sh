#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/generate_changelog.sh --from <ref> [--to <ref>]

Generate a Keep a Changelog-style markdown draft from git commits in an explicit
ref range. The output is intended for maintainer review and manual editing.

Options:
  --from <ref>  Required lower bound git ref (exclusive)
  --to <ref>    Optional upper bound git ref (inclusive), defaults to HEAD
  --help        Show this help text
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

trim_whitespace() {
  printf '%s' "$1" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

normalize_subject() {
  local subject
  local pr_suffix=""
  local prefix_stripped

  subject="$(trim_whitespace "$1")"
  if [[ "${subject}" =~ ^(.*)( \(#[0-9]+\))$ ]]; then
    subject="${BASH_REMATCH[1]}"
    pr_suffix="${BASH_REMATCH[2]}"
  fi

  subject="$(printf '%s' "${subject}" | sed -E 's/^[[:space:]]*[*-][[:space:]]+//')"
  prefix_stripped="$(printf '%s' "${subject}" | sed -E 's/^[[:alnum:]_.\/-]+(\([^)]+\))?!?:[[:space:]]*//')"
  if [[ -n "${prefix_stripped}" && "${prefix_stripped}" != "${subject}" ]]; then
    subject="${prefix_stripped}"
  fi

  subject="$(trim_whitespace "${subject}")"
  subject="${subject%.}"

  if [[ -n "${subject}" ]]; then
    subject="${subject^}"
  fi

  printf '%s%s' "${subject}" "${pr_suffix}"
}

categorize_subject() {
  local lower

  lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"

  if [[ "${lower}" =~ (^|[^[:alpha:]])(security|cve|vuln|vulnerability|harden|hardening|sanitize|auth)([^[:alpha:]]|$) ]]; then
    printf 'Security'
  elif [[ "${lower}" =~ ^(feat|add|introduce|implement|support|enable|create|new)(\(|:|!|[[:space:]]) ]] || \
       [[ "${lower}" =~ (^|[^[:alpha:]])(add|introduce|implement|support|enable|create)([^[:alpha:]]|$) ]]; then
    printf 'Added'
  elif [[ "${lower}" =~ ^(fix|bugfix|hotfix)(\(|:|!|[[:space:]]) ]] || \
       [[ "${lower}" =~ (^|[^[:alpha:]])(fix|fixed|bug|bugs|regression|repair|resolve|resolved|correct)([^[:alpha:]]|$) ]]; then
    printf 'Fixed'
  else
    printf 'Changed'
  fi
}

append_entry() {
  local category="$1"
  local entry="$2"

  case "${category}" in
    Added)
      added_entries+=("${entry}")
      ;;
    Changed)
      changed_entries+=("${entry}")
      ;;
    Fixed)
      fixed_entries+=("${entry}")
      ;;
    Security)
      security_entries+=("${entry}")
      ;;
    *)
      changed_entries+=("${entry}")
      ;;
  esac
}

print_section() {
  local title="$1"
  shift

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  printf '### %s\n' "${title}"
  for entry in "$@"; do
    printf -- '- %s\n' "${entry}"
  done
  printf '\n'
}

ensure_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "must be run inside a git repository"
}

ensure_ref() {
  local ref="$1"
  git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1 || die "unknown git ref: ${ref}"
}

from_ref=""
to_ref="HEAD"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --from)
      shift
      [[ "$#" -gt 0 ]] || die "--from requires a git ref"
      from_ref="$1"
      ;;
    --to)
      shift
      [[ "$#" -gt 0 ]] || die "--to requires a git ref"
      to_ref="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
  shift
done

[[ -n "${from_ref}" ]] || die "--from is required"

ensure_repo
ensure_ref "${from_ref}"
ensure_ref "${to_ref}"

resolved_from="$(git rev-parse "${from_ref}^{commit}")"
resolved_to="$(git rev-parse "${to_ref}^{commit}")"

declare -a added_entries=()
declare -a changed_entries=()
declare -a fixed_entries=()
declare -a security_entries=()

while IFS= read -r -d $'\x1e' raw_subject; do
  raw_subject="$(trim_whitespace "${raw_subject}")"
  [[ -n "${raw_subject}" ]] || continue
  [[ "${raw_subject}" == Merge\ pull\ request* ]] && continue

  normalized_subject="$(normalize_subject "${raw_subject}")"
  [[ -n "${normalized_subject}" ]] || continue

  category="$(categorize_subject "${raw_subject}")"
  append_entry "${category}" "${normalized_subject}"
done < <(git log --no-merges --reverse --format='%s%x1e' "${resolved_from}..${resolved_to}")

printf '<!-- Draft changelog generated from %s..%s. Review and edit before publishing. -->\n\n' "${resolved_from}" "${resolved_to}"
printf '## [Unreleased]\n\n'

if [[ "${#added_entries[@]}" -eq 0 ]] && \
   [[ "${#changed_entries[@]}" -eq 0 ]] && \
   [[ "${#fixed_entries[@]}" -eq 0 ]] && \
   [[ "${#security_entries[@]}" -eq 0 ]]; then
  printf '_No notable changes in this range._\n'
  exit 0
fi

print_section "Added" "${added_entries[@]}"
print_section "Changed" "${changed_entries[@]}"
print_section "Fixed" "${fixed_entries[@]}"
print_section "Security" "${security_entries[@]}"
