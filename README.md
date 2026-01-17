# codex-yolo

Run the OpenAI Codex CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Codex with `--yolo`
and `--search`.

## Requirements

- Docker (Desktop or Engine)
- Bash (macOS/Linux; Windows via WSL recommended)
- Docker Buildx (recommended for reliable builds)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh | bash
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
- `CODEX_YOLO_IMAGE` (default: `codex-cli-yolo:local`)
- `CODEX_YOLO_HOME` (default: `/home/codex`)
- `CODEX_YOLO_WORKDIR` (default: `/workspace`)
- `CODEX_BUILD_NO_CACHE=1` to build without cache
- `CODEX_BUILD_PULL=1` to pull the base image during build
- `CODEX_SKIP_VERSION_CHECK=1` to skip npm version checks and reuse the existing image
- `CODEX_DRY_RUN=1` to print the computed docker build/run commands without executing
- `--pull` flag to force a pull when running `./.codex_yolo.sh`
- Each run checks npm for the latest `@openai/codex` version (unless skipped)
  and rebuilds the image if it is out of date.

## Security note

`codex_yolo` deliberately does not forward your SSH agent or mount `~/.ssh` into the container. This keeps the blast radius smaller when running the Codex CLI in `--yolo` mode, at the cost of private repo access from inside the container.

## Update

Update the wrapper scripts by re-running the installer (it overwrites the
files inside `CODEX_YOLO_DIR`):

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh | bash
```

If you installed from a fork or branch, pass those again:

```bash
CODEX_YOLO_REPO="yourname/codex_yolo" \
CODEX_YOLO_BRANCH="main" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourname/codex_yolo/main/install.sh)"
```

The Codex CLI image updates automatically when you run `codex_yolo`. To force
a rebuild or pull:

```bash
CODEX_BUILD_NO_CACHE=1 codex_yolo
# or
codex_yolo --pull
```

## License

MIT. See `LICENSE`.
