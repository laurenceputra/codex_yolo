# codex-yolo

Run the OpenAI Codex CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Codex with `--yolo`
and `--search`. Only the current directory is mounted into the container by
default, so other host paths are not visible unless you add additional mounts.

## Requirements

- Docker (Desktop or Engine)
- Bash (macOS/Linux; Windows via WSL recommended)
- Docker Buildx (recommended for reliable builds): https://docs.docker.com/build/buildx/

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

By default, your current repo is mounted into the container at `/workspace`,
so make sure you run `codex_yolo` from the repo you want Codex to access.

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

## Troubleshooting

- **Docker not found / daemon not running:** install Docker and start the Docker
  service, then re-run `codex_yolo` (see Requirements above for links).
- **Files missing inside the container:** only the current directory is mounted
  by default. Run `codex_yolo` from the repo you want to work on.

## Configuration

- `CODEX_BASE_IMAGE` (default: `node:20-slim`)
- `CODEX_YOLO_IMAGE` (default: `codex-cli-yolo:local`; only set to images you trust)
- `CODEX_YOLO_HOME` (default: `/home/codex`; advanced, must be an absolute container path)
- `CODEX_YOLO_WORKDIR` (default: `/workspace`; advanced, must be an absolute container path)
- `CODEX_YOLO_CLEANUP` (default: `1`) to chown `/workspace` to your UID on exit; set to `0` to skip
- `CODEX_YOLO_REPO` (default: `laurenceputra/codex_yolo`) to specify a different repository for updates
- `CODEX_YOLO_BRANCH` (default: `main`) to specify a different branch for updates
- `CODEX_SKIP_UPDATE_CHECK=1` to skip automatic update checks
- `CODEX_BUILD_NO_CACHE=1` to build without cache
- `CODEX_BUILD_PULL=1` to pull the base image during build
- `CODEX_SKIP_VERSION_CHECK=1` to skip npm version checks and reuse an existing image; requires that the image already exists (for example from a previous run), otherwise the script may fail instead of building it
- `CODEX_DRY_RUN=1` to print the computed docker build/run commands without executing
- `--pull` flag to force a pull when running `./.codex_yolo.sh`
- Each run checks npm for the latest `@openai/codex` version (unless skipped)
  and rebuilds the image if it is out of date.
- Each run checks for codex_yolo script updates (unless skipped with `CODEX_SKIP_UPDATE_CHECK=1`)
  and auto-updates if a new version is available.

## Security note

`codex_yolo` deliberately does not forward your SSH agent or mount `~/.ssh` into the container. This keeps the blast radius smaller when running the Codex CLI in `--yolo` mode, at the cost of private repo access from inside the container.

The container enables passwordless `sudo` for the mapped user to allow system installs. Use with care; `sudo` writes into `/workspace` are cleaned up via a chown on exit, but they still run as root inside the container.

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
