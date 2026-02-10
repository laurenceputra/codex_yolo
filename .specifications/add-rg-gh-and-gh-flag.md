# Spec: Add `rg`, `gh`, and Optional `--gh` Host Copilot Mount

## Status
Proposed

## Context
`codex_yolo` currently installs core tools (`git`, `openssh-client`, etc.) in the runtime image and supports optional SSH key mounting via `--mount-ssh`. The current image does not include:
- `rg` (ripgrep), which is expected by agent workflows for fast search.
- `gh` (GitHub CLI), which is required for GitHub-native workflows (PRs, checks, metadata lookups).

Additionally, there is no explicit runtime path for sharing host GitHub CLI/Copilot state into the container.

## Problem Statement
Users need to run `rg` and `gh` inside the container consistently. For `gh`, users also need an explicit opt-in mode that mounts host Copilot state into the container. This mode must clearly depend on host-side GitHub CLI authentication state and fail fast when prerequisites are not met.

## Goals
1. Add `rg` and `gh` binaries to the Docker image used by `codex_yolo`.
2. Add a new wrapper flag `--gh` that mounts host `~/.copilot` into the container at `${CONTAINER_HOME}/.copilot`.
3. Enforce that `--gh` only runs when the host machine is already logged into GitHub via `gh`.
4. Document behavior, prerequisites, and security implications in user-facing docs.
5. Add/adjust tests to cover the new flag and image tool availability assumptions.

## Non-Goals
- Automatic GitHub login from inside `codex_yolo`.
- Managing or modifying host authentication state.
- SSH key mounting changes beyond existing `--mount-ssh` behavior.

## Functional Requirements
1. Docker image build installs `ripgrep` and `gh` packages.
2. Wrapper recognizes `--gh` as a codex_yolo-only flag (not forwarded to `codex`).
3. When `--gh` is set:
   - Verify `gh` exists on host (`command -v gh`).
   - Verify host auth is valid (`gh auth status`).
   - Verify `${HOME}/.copilot` exists and is a directory.
   - Mount `${HOME}/.copilot` read-write into `${CONTAINER_HOME}/.copilot`.
4. If any `--gh` prerequisite fails, exit with a clear actionable error.
5. If `CODEX_DRY_RUN=1`, output must include the `~/.copilot` mount when `--gh` is provided.
6. Shell completion includes `--gh`.
7. README/EXAMPLES mention:
   - `--gh` usage.
   - Host must already be authenticated with `gh`.
   - `~/.copilot` mount scope and implications.

## Behavioral Rules
- `--gh` is opt-in and disabled by default.
- Existing behavior for users not using `--gh` is unchanged.
- `--gh` and `--mount-ssh` can be used together.
- Failure messages should be explicit about missing command (`gh`), auth status, or missing `~/.copilot`.

## Security Considerations
- Mounting host `~/.copilot` extends container access to host-stored Copilot/GitHub context data.
- Keep mount scoped only to `~/.copilot`; do not broaden host path access.
- Preserve existing warning posture for privileged capabilities (similar to `--mount-ssh`).

## Implementation Notes
1. `.codex_yolo.Dockerfile`
   - Add `ripgrep` and `gh` to apt package list.
2. `.codex_yolo.sh`
   - Add `MOUNT_GH=0` state variable.
   - Parse `--gh` flag.
   - Add prerequisite checks and mount logic.
   - Keep dry-run output aligned with actual `docker run` args.
3. Completion files
   - Add `--gh` to `.codex_yolo_completion.bash` and `.codex_yolo_completion.zsh`.
4. Tests
   - Extend integration test suite with a dry-run test verifying `--gh` adds `.copilot` mount when prerequisites are satisfied.
5. Docs
   - Update README and EXAMPLES with concise `--gh` guidance and prerequisite statement.

## Acceptance Criteria
1. Building the image installs both `rg` and `gh`.
2. Running `codex_yolo --gh` on a host with:
   - `gh` installed,
   - valid `gh auth status`, and
   - existing `~/.copilot`
   results in a container run command containing `-v ~/.copilot:${CONTAINER_HOME}/.copilot`.
3. Running `codex_yolo --gh` fails fast with clear errors when any prerequisite is missing.
4. Dry-run output reflects real mount behavior for `--gh`.
5. Completion scripts include `--gh`.
6. README and EXAMPLES document `--gh` behavior and host-auth prerequisite.

## Validation Plan
1. Static validation:
   - `bash -n .codex_yolo.sh .codex_yolo_entrypoint.sh .codex_yolo_diagnostics.sh tests/integration_tests.sh`
2. Test suite:
   - `./tests/integration_tests.sh`
3. Targeted dry-run check:
   - In a temp HOME with fake `.copilot`, with host `gh auth status` available, run:
     - `CODEX_DRY_RUN=1 CODEX_SKIP_UPDATE_CHECK=1 ./.codex_yolo.sh --gh`
   - Confirm output includes `.copilot` mount.

## Risks and Mitigations
- Risk: distro package naming/availability differences for `gh`.
  - Mitigation: use Debian package `gh` on `node:20-slim` (Debian-based), validated in CI build.
- Risk: users expect `--gh` to auto-login.
  - Mitigation: explicit error text and documentation clarifying host login prerequisite.

## Rollout Notes
- Backward compatible for existing users.
- Users who need GitHub CLI workflows opt in with `--gh`.
