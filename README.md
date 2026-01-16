# codex-yolo

Run the OpenAI Codex CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Codex with `--yolo`
and `--search`.

## Requirements

- Docker (Desktop or Engine)
- Bash (macOS/Linux; Windows via WSL recommended)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh | bash
```

Non-interactive install (no prompt):

```bash
NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh)"
```

By default this installs into `~/.codex_yolo` and sources it from your shell
profile. You can override paths:

```bash
CODEX_YOLO_DIR="$HOME/.codex_yolo" \
CODEX_YOLO_PROFILE="$HOME/.zshrc" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh)"
```

## Quick start

```bash
codex_yolo
```

Pass-through arguments are forwarded to `codex`:

```bash
codex_yolo --help
```

## Login

The first run will prompt you to sign in. You can also log in explicitly:

```bash
codex_yolo login
```

For headless or remote environments, use device auth:

```bash
codex_yolo login --device-auth
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
