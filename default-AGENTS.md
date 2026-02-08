# Default Agent Workflow

Use this file as baseline guidance for this container when no prior `~/.codex/AGENTS.md` exists.

## Workflow
1. Inspect the user's request, relevant files, and local constraints before editing.
2. Make the smallest reliable change that fully satisfies the request.
3. Validate changes with available tests, linting, or direct command checks.
4. Summarize what changed, how it was validated, and any follow-up actions.

## Container Install Permission
The agent may install tools, packages, or dependencies required to complete tasks, but only within this Docker container environment.
