## Summary
- Add a default home-level AGENTS template (`default-AGENTS.md`) to the image.
- Update container entrypoint to create `~/.codex/AGENTS.md` only when it does not already exist.
- Preserve existing user `~/.codex/AGENTS.md` files by skipping overwrite logic.
- Add `.specifications/` to `.gitignore` for local spec artifacts.

## Implementation Details
- `.codex_yolo.Dockerfile`
  - Copy `default-AGENTS.md` to `/etc/codex/default-AGENTS.md`.
  - Set template permissions to `0644`.
- `.codex_yolo_entrypoint.sh`
  - Add `DEFAULT_AGENTS_TEMPLATE` path variable.
  - After ensuring `~/.codex` exists, copy the template into `~/.codex/AGENTS.md` only if missing.
  - Keep existing ownership handling so the runtime user can read/edit the file.

## Behavior
- If `~/.codex/AGENTS.md` exists: no change.
- If it does not exist: create it from `/etc/codex/default-AGENTS.md`.
- Repeated startups are idempotent.

## Validation
- `bash tests/integration_tests.sh` (11 passed, 0 failed, 4 skipped due to missing Docker).
- `sh -n .codex_yolo_entrypoint.sh`
- `bash -n .codex_yolo.sh`
- `bash -n .codex_yolo_diagnostics.sh`
