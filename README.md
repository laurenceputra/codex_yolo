# codex-yolo

Run the OpenAI Codex CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Codex with `--yolo`
and `--search`.

## Requirements

- Docker (Desktop or Engine)
- Bash (macOS/Linux; Windows via WSL recommended)

## Quick start

```bash
./.codex_yolo.sh
```

Pass-through arguments are forwarded to `codex`:

```bash
./.codex_yolo.sh --help
```

## Login

The first run will prompt you to sign in. You can also log in explicitly:

```bash
./.codex_yolo.sh login
```

For headless or remote environments, use device auth:

```bash
./.codex_yolo.sh login --device-auth
```

Device auth may need to be enabled in your ChatGPT security settings first.
The container mounts `~/.codex` from your host, so file-based credential caches
are shared between runs.

## Configuration

- `CODEX_BASE_IMAGE` (default: `node:20-slim`)
- `CODEX_BUILD_NO_CACHE=1` to build without cache
- `CODEX_BUILD_PULL=1` to pull the base image during build
- `--pull` flag to force a pull when running `./.codex_yolo.sh`

## License

MIT. See `LICENSE`.
