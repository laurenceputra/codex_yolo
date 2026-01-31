# codex-yolo

Run the OpenAI Codex CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Codex with `--yolo`
and `--search`. By default, only your current directory, `~/.codex` credentials,
and `~/.gitconfig` are mounted into the container. Other host paths are not
visible, keeping the environment isolated and secure.

## ✨ What's New in v1.1.0

Version 1.1.0 brings major improvements to usability, troubleshooting, and developer experience:

### 🔍 Diagnostics & Troubleshooting
- **Health Check Command**: Run `codex_yolo diagnostics` (or `doctor`, `health`) to check your system configuration
- **Verbose Mode**: Use `--verbose` or `-v` flag for detailed debugging output
- **Better Error Messages**: All errors now include actionable suggestions

### ⚙️ Configuration Management
- **Persistent Config**: Set preferences in `~/.codex_yolo/config` (or `${INSTALL_DIR}/config`)
- **Example Template**: See `.codex_yolo.conf.example` in your install directory
- **Version Commands**: Check your version with `codex_yolo version` or `--version`

### 🚀 Developer Experience
- **Shell Completion**: Tab completion for bash and zsh (optional install)
- **Comprehensive Examples**: See `EXAMPLES.md` for common use cases and best practices
- **Documentation**: Full changelog in `CHANGELOG.md`

### 🔧 Engineering Quality
- **Test Suite**: 14 integration tests ensure reliability
- **CI/CD Pipeline**: Automated testing on every change
- **Better Code Organization**: Modular, maintainable codebase

**Upgrading from v1.0.x?** See the [Migration Guide](#migration-from-v10x) below. All changes are backward compatible.

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

## Diagnostics and Help

Check your system health and configuration:

```bash
codex_yolo diagnostics  # or: doctor, health
```

Show version:

```bash
codex_yolo --version
```

Enable verbose output:

```bash
codex_yolo --verbose
# or
CODEX_VERBOSE=1 codex_yolo
```

For more examples and use cases, see [EXAMPLES.md](EXAMPLES.md).

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

## What gets mounted from the host

`codex_yolo` mounts the following paths from your host system into the container:

- **Current directory** → `/workspace` (read-write): Your repository code. Make sure to run `codex_yolo` from the directory you want to work on.
- **`~/.codex`** → `~/.codex` (read-write): Credential caches for ChatGPT authentication tokens, shared between runs.
- **`~/.gitconfig`** → `~/.gitconfig` (read-only): Your Git configuration (only if the file exists on your host). This allows Git commands inside the container to use your name, email, and other Git settings. **Important:** When the Codex CLI makes commits, it will use your `user.name` and `user.email` from this file instead of the default "Codex Fix <fix@codex-yolo.local>" identity.

For security reasons, `codex_yolo` **does not** mount by default:
- `~/.ssh` - SSH keys are not available inside the container by default
- SSH agent forwarding is disabled
- No other host directories are mounted by default

This minimal mounting approach keeps the blast radius smaller when running in `--yolo` mode.

### Optional: Enable SSH for git push

If you need the Codex agent to push changes to remote repositories, you can enable SSH mounting:

```bash
# Enable SSH mounting with the --mount-ssh flag
codex_yolo --mount-ssh
```

**⚠️ Security Warning**: When SSH mounting is enabled:
- Your `~/.ssh` directory is mounted read-only into the container
- Codex agents can use your SSH keys to push to remote repositories
- **You should protect critical branches** in your repository settings (e.g., require pull requests, enable branch protection rules)
- Only enable this if you trust the Codex agent and understand the security implications

## Troubleshooting

Run diagnostics to check your setup:

```bash
codex_yolo diagnostics
```

Common issues:

- **Docker not found / daemon not running:** install Docker and start the Docker
  service, then re-run `codex_yolo` (see Requirements above for links).
- **Files missing inside the container:** only the current directory is mounted
  by default. Run `codex_yolo` from the repo you want to work on.

For more detailed troubleshooting, see [EXAMPLES.md](EXAMPLES.md).

## Configuration

Configuration can be set via environment variables or a config file. Config files are checked in this order (later sources take precedence):

1. `${INSTALL_DIR}/config` (installation directory, e.g., `~/.codex_yolo/config`)
2. `~/.codex_yolo/config` (user config directory, same as above in default install)
3. Environment variables - Highest precedence

See `.codex_yolo.conf.example` in your installation directory for a template.

Available options:

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
- `CODEX_VERBOSE=1` to enable verbose logging
- `--pull` flag to force a pull when running `./.codex_yolo.sh`
- `--verbose` or `-v` flag to enable verbose output
- `--mount-ssh` flag to enable SSH key mounting for git push access; see security warning above
- Each run checks npm for the latest `@openai/codex` version (unless skipped)
  and rebuilds the image if it is out of date.
- Each run checks for codex_yolo script updates (unless skipped with `CODEX_SKIP_UPDATE_CHECK=1`)
  and auto-updates if a new version is available.

## Shell Completion

Enable tab completion for bash or zsh:

```bash
# Bash
source ~/.codex_yolo/.codex_yolo_completion.bash

# Zsh
source ~/.codex_yolo/.codex_yolo_completion.zsh
```

Add these lines to your `.bashrc` or `.zshrc` for persistent completion.

## Security note

`codex_yolo` deliberately limits what gets mounted from the host. See the "What gets mounted from the host" section above for details. By default, your SSH agent is not forwarded and `~/.ssh` is not mounted, keeping the blast radius smaller when running in `--yolo` mode. This comes at the cost of private repo access from inside the container unless you explicitly enable SSH mounting with the `--mount-ssh` flag (see above for security considerations).

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

## Migration from v1.0.x

Version 1.1.0 is **fully backward compatible** with v1.0.x. All existing scripts and workflows will continue to work without modification.

### Automatic Updates

The auto-update mechanism will automatically download new features when you run `codex_yolo`:
- Core scripts update automatically (as in v1.0.x)
- New optional files (completion scripts, examples) are downloaded on fresh install or manual re-install

### New Files in v1.1.0

After upgrading, your `~/.codex_yolo` directory will contain new files:
- `.codex_yolo_diagnostics.sh` - Health check system (auto-downloaded)
- `.codex_yolo_completion.bash` - Bash completion (optional, via re-install)
- `.codex_yolo_completion.zsh` - Zsh completion (optional, via re-install)
- `.codex_yolo.conf.example` - Configuration template (optional, via re-install)
- `EXAMPLES.md` - Usage guide (optional, via re-install)

### Getting All New Features

To get optional files, re-run the installer:
```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh | bash
```

### Configuration Files

v1.1.0 adds support for persistent configuration. Config files are checked in this order:
1. `${INSTALL_DIR}/config` (installation directory, e.g., `~/.codex_yolo/config`)
2. `~/.codex_yolo/config` (user config directory, same as above in default install)
3. Environment variables (highest precedence, override config files)

Old versions (v1.0.x) will simply ignore these files if they exist.

### Backward Compatibility Guarantee

- **v1.0.x clients can still auto-update**: Old versions will download core files they understand
- **No breaking changes**: All v1.0.x commands and environment variables work identically
- **Graceful degradation**: New commands (like `diagnostics`) won't break old versions, they'll just show "command not found"
- **Safe to mix versions**: You can run v1.0.x and v1.1.0 in different environments safely

## Documentation

- **[EXAMPLES.md](EXAMPLES.md)** - Common usage patterns and best practices
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[TECHNICAL.md](TECHNICAL.md)** - Architecture, development guide, and technical details

## Getting Help

If you encounter issues:

1. **Run diagnostics**: `codex_yolo diagnostics` - Check your system configuration
2. **Check examples**: See [EXAMPLES.md](EXAMPLES.md) for common use cases
3. **Review changelog**: See [CHANGELOG.md](CHANGELOG.md) for recent changes
4. **Technical details**: See [TECHNICAL.md](TECHNICAL.md) for architecture and troubleshooting

## License

MIT. See `LICENSE`.
