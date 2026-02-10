## Summary
- Added `gh` and `ripgrep` (`rg`) to the Docker image so both tools are available inside `codex_yolo` containers.
- Added a new `--gh` wrapper flag that mounts host `~/.copilot` into the container at `~/.copilot`.
- Added host-side prerequisite enforcement for `--gh`: host `gh` must be installed, `gh auth status` must succeed, and `~/.copilot` must exist.
- Updated bash/zsh completions to include `--gh`.
- Updated README and EXAMPLES with `--gh` usage, prerequisites, and security notes.
- Added/updated integration tests for Dockerfile package coverage and `--gh` dry-run mount behavior.
- Added implementation spec at `.specifications/add-rg-gh-and-gh-flag.md`.

## Problem
The container did not include `rg` or `gh`, and there was no explicit path to run GitHub CLI workflows that need host Copilot state. Users also needed clear guardrails that `--gh` only works when host-side `gh` authentication is already configured.

## Solution
- Docker image installs `gh` and `ripgrep` via apt.
- `--gh` is parsed as a wrapper-only flag and not forwarded to `codex`.
- When `--gh` is set, wrapper now:
  - checks `gh` exists on host,
  - checks host authentication with `gh auth status`,
  - checks `~/.copilot` exists,
  - mounts `~/.copilot` into container home.
- Added actionable error messages for each failed prerequisite.

## Validation
- `bash -n .codex_yolo.sh .codex_yolo_entrypoint.sh .codex_yolo_diagnostics.sh install.sh tests/integration_tests.sh`
- `./tests/integration_tests.sh`
  - Result: passed with Docker-dependent tests skipped in this execution environment.

## Notes
- `--gh` is opt-in and can be used alongside `--mount-ssh`.
- Host must already be logged in with `gh auth login` for `--gh` to succeed.
