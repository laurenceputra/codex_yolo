# Changelog

All notable changes to codex_yolo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.9] - 2026-03-29

### Changed
- Replace Charm's `gum` package with `bubblewrap` in the Docker image.
- Remove the extra Charm apt repository setup that was only needed for `gum`.
- Bump the project version from 1.1.8 to 1.1.9.

## [1.1.8] - 2026-03-29

### Added
- Install Charm's `gum` CLI in the Docker image so Bubblegum tooling is available in the container environment.

### Changed
- Bump the project version from 1.1.7 to 1.1.8.

## [1.1.0] - 2026-01-31

### Added - Product Perspective
- **Health Check Command**: New `codex_yolo diagnostics` (aliases: `doctor`, `health`) command for comprehensive system diagnostics
  - Checks Docker installation and status
  - Verifies image status and versions
  - Validates configuration and permissions
  - Provides actionable recommendations
- **Configuration File Support**: Persistent configuration via `~/.codex_yolo.conf` or `~/.codex_yolo/config`
  - Example config file included (`.codex_yolo.conf.example`)
  - Environment variables still take precedence
- **Version Commands**:
  - `codex_yolo version` - Show version number
  - `codex_yolo --version` - Show version with label

### Added - User Experience Perspective
- **Verbose Mode**: Enable detailed logging with `--verbose` or `-v` flag or `CODEX_VERBOSE=1`
- **Improved Error Messages**: Better error messages with actionable suggestions and troubleshooting hints
- **Shell Completion**: Tab completion support for bash and zsh
  - Completes commands, flags, and common options
  - Installation instructions in README
- **Comprehensive Examples**: New `EXAMPLES.md` with:
  - Common use cases and workflows
  - Best practices
  - Troubleshooting guide
  - Integration examples
- **Better Onboarding**: Improved install script output with next steps and helpful links

### Added - Senior Engineering Perspective
- **Test Suite**: Comprehensive integration tests (`tests/integration_tests.sh`)
  - Script validation
  - Command testing
  - Configuration validation
  - Exit status checks
- **CI/CD Pipeline**: GitHub Actions workflow for:
  - Automated testing on push/PR
  - Docker build validation
  - Linting and file validation
  - Version format checking
- **Structured Logging**: Helper functions for consistent logging:
  - `log_info()` for informational messages
  - `log_error()` for errors
  - `log_verbose()` for debug output
- **Better Code Organization**: Improved modularity and maintainability
- **Documentation**:
  - Added CHANGELOG.md
  - Added EXAMPLES.md
  - Enhanced README.md with new features
  - Added inline documentation for complex logic

### Changed
- Auto-update now downloads all files including completion scripts and examples
- Install script now downloads completion scripts and documentation
- Improved install script output with better user guidance
- Config file loading now supports installation directory (`${INSTALL_DIR}/config`)
- Version bumped from 1.0.2 to 1.1.0

### Security
- No security vulnerabilities introduced
- Maintained minimal host mounting security model
- No changes to container isolation

## [1.0.2] - Previous Release

Previous release with basic functionality. See git history for details.

[1.1.0]: https://github.com/laurenceputra/codex_yolo/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/laurenceputra/codex_yolo/releases/tag/v1.0.2
