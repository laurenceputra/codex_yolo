# Technical Documentation - codex_yolo

This document provides technical details for developers working on codex_yolo.

## Architecture Overview

codex_yolo is a bash wrapper that runs OpenAI's Codex CLI in an isolated Docker container. The tool prioritizes security through minimal host mounting and provides operational tooling for troubleshooting.

### Core Components

**Main Script** (`.codex_yolo.sh`)
- Configuration loading with cascading precedence
- Auto-update mechanism
- Docker image management
- Container orchestration

**Diagnostics** (`.codex_yolo_diagnostics.sh`)
- System health validation
- Docker environment checks
- Configuration verification
- Actionable recommendations

**Installation** (`install.sh`)
- Platform detection (macOS, Linux, WSL)
- Shell profile integration
- File deployment

**Container** (`.codex_yolo.Dockerfile`, `.codex_yolo_entrypoint.sh`)
- Node.js 20 base image
- Codex CLI installation
- User mapping for file permissions
- Git identity propagation

## Design Decisions

### Configuration Priority

Config files are loaded in ascending priority order:

```bash
1. ${INSTALL_DIR}/config      # Team/system defaults (e.g., ~/.codex_yolo/config)
2. ~/.codex_yolo/config       # User config directory (same as above in default install)
3. Environment variables      # Highest priority
```

**Rationale**: Keeps config centralized in `~/.codex_yolo` directory. Allows team defaults while enabling user overrides. Environment variables maintain highest priority for CI/CD and one-off customization.

### Security Model

**Minimal Host Mounting**:
- Only current directory (read-write)
- `~/.codex` credentials (read-write)
- `~/.gitconfig` (read-only)

**Optional Mounting** (disabled by default):
- `~/.ssh` (SSH keys, read-only) - Enable with `CODEX_MOUNT_SSH=1`

**Intentionally NOT Mounted by default**:
- `~/.ssh` (SSH keys) - Must be explicitly enabled
- SSH agent forwarding - Not supported
- Other home directory contents

**Rationale**: Limits blast radius in `--yolo` mode. Private repository access requires explicit setup (`CODEX_MOUNT_SSH=1`), preventing accidental exposure. When SSH is enabled, users are warned to protect critical branches.

### Auto-Update Strategy

Core files update automatically on every run (unless disabled):
- `.codex_yolo.sh`
- `.codex_yolo.Dockerfile`
- `.codex_yolo_entrypoint.sh`
- `.codex_yolo_diagnostics.sh`
- `VERSION`

Optional files downloaded separately:
- Completion scripts
- Example configuration
- Documentation

**Rationale**: Ensures users get critical fixes while allowing graceful degradation for optional features. Backward compatible with v1.0.x auto-update logic.

## Code Organization

### File Structure

```
.codex_yolo.sh                 # Main wrapper script
.codex_yolo.Dockerfile         # Container image definition
.codex_yolo_entrypoint.sh      # Container initialization
.codex_yolo_diagnostics.sh     # Health check system
.codex_yolo_completion.bash    # Bash tab completion
.codex_yolo_completion.zsh     # Zsh tab completion
.codex_yolo.conf.example       # Configuration template
install.sh                     # Installation script
VERSION                        # Version tracking
```

### Key Functions

**log_verbose(), log_info(), log_error()** - Structured logging
```bash
VERBOSE="${CODEX_VERBOSE:-0}"
log_verbose() { [[ "${VERBOSE}" == "1" ]] && echo "[VERBOSE] $*" >&2; }
```

**Config Loading** - Cascading configuration
```bash
if [[ -f "${SCRIPT_DIR}/config" ]]; then source "${SCRIPT_DIR}/config"; fi
if [[ -f "${HOME}/.codex_yolo/config" ]]; then source "${HOME}/.codex_yolo/config"; fi
```

**Auto-Update** - Version checking and file download
```bash
remote_version="$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION")"
if [[ "${remote_version}" != "${local_version}" ]]; then
    # Download and install updates
fi
```

## Testing Strategy

### Integration Tests

Location: `tests/integration_tests.sh`

**Test Coverage**:
1. File existence and permissions
2. Shell script syntax validation
3. Version commands
4. Diagnostics functionality
5. Doctor alias
6. Dry run mode
7. Completion files
8. Configuration files
9. Config file loading
10. Config priority (3 locations)

**Running Tests**:
```bash
./tests/integration_tests.sh
```

Expected output: All tests pass (14/14)

### Manual Testing Checklist

Before releases:
- [ ] Clean install on Linux, macOS
- [ ] Update from v1.0.x
- [ ] Config file precedence
- [ ] Diagnostics command
- [ ] Version commands
- [ ] Verbose mode
- [ ] Docker image build
- [ ] Container execution
- [ ] Git identity propagation

## CI/CD Pipeline

### GitHub Actions Workflow

Location: `.github/workflows/ci.yml`

**Jobs**:

1. **test** - Integration tests
   - Checkout code
   - Setup Docker Buildx
   - Validate syntax
   - Run integration tests

2. **build** - Docker image
   - Build test image
   - Verify Codex binary
   - Check version file

3. **lint** - Code quality
   - File permissions
   - Trailing whitespace
   - Markdown validation
   - Version format

**Triggers**: Push to main, pull requests

## Version Management

### Semantic Versioning

Format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

Current: v1.1.0

### Release Process

1. Update VERSION file
2. Update CHANGELOG.md
3. Tag release: `git tag v1.1.0`
4. Push with tags: `git push --tags`
5. Auto-update delivers to users

## Development Guidelines

### Adding New Features

1. **Update main script** (`.codex_yolo.sh`)
   - Add feature implementation
   - Update help text if applicable
   - Maintain backward compatibility

2. **Add tests** (`tests/integration_tests.sh`)
   - Create new test case
   - Verify all tests pass
   - Update test count in summary

3. **Update documentation**
   - README.md for user features
   - EXAMPLES.md for usage patterns
   - CHANGELOG.md for version history
   - This file for technical details

4. **Test auto-update**
   - Ensure new files are downloaded
   - Test v1.0.x compatibility
   - Verify graceful degradation

### Code Style

**Shell Script Standards**:
- Use `set -euo pipefail`
- Quote all variables
- Use `[[ ]]` for conditionals
- Validate with `bash -n`
- Prefer long-form flags

**Error Handling**:
- Provide actionable error messages
- Reference diagnostics command
- Include relevant documentation links
- Exit with appropriate status codes

### Debugging

**Enable verbose mode**:
```bash
CODEX_VERBOSE=1 codex_yolo
```

**Dry run mode**:
```bash
CODEX_DRY_RUN=1 codex_yolo
```

**Check diagnostics**:
```bash
codex_yolo diagnostics
```

**Docker logs**:
```bash
docker logs <container_id>
```

## Performance Considerations

### Image Caching

Docker images are cached after first build. Subsequent runs are fast unless:
- Codex CLI version changes
- Base image updates
- Forced rebuild requested

### Auto-Update Optimization

Version check happens once per run:
- Skip with `CODEX_SKIP_UPDATE_CHECK=1`
- Uses GitHub raw URLs (cached by CDN)
- Downloads only when version differs

### Build Optimization

- Multi-stage Dockerfile not needed (single stage)
- Minimal dependencies (`node:20-slim`)
- Layer caching for apt packages
- BuildKit recommended for reliability

## Security Considerations

### Credential Handling

**Safe**:
- `~/.codex` mounted read-write for OAuth tokens
- Temporary credentials in container memory
- No persistent storage in image

**Not Mounted by default**:
- SSH keys (`~/.ssh`) - Can be enabled with `CODEX_MOUNT_SSH=1`
- Cloud provider credentials
- Other sensitive files

### Container Isolation

- No privileged mode
- No host network access
- Limited filesystem access
- Cleanup on exit (chown workspace)

### Sudo Access

Container enables passwordless sudo:
- Allows `apt install` for dependencies
- Runs as mapped user (not root)
- Workspace chown on exit

**Rationale**: Codex may need to install packages. Risk mitigated by container isolation.

## Troubleshooting Development Issues

### Auto-Update Not Working

1. Check `CODEX_SKIP_UPDATE_CHECK` not set
2. Verify network connectivity
3. Check GitHub API rate limits
4. Review curl error messages

### Tests Failing

1. Run with verbose: `bash -x tests/integration_tests.sh`
2. Check Docker daemon running
3. Verify file permissions
4. Review test-specific output

### Build Failures

1. Check Docker version
2. Enable BuildKit: `DOCKER_BUILDKIT=1`
3. Build with no cache: `CODEX_BUILD_NO_CACHE=1`
4. Check npm registry availability

## Future Enhancements

### Considered But Deferred

**Telemetry/Analytics**
- Requires privacy considerations
- Needs opt-in mechanism
- Deferred for future version

**Interactive Shell Mode**
- Would require persistent containers
- Architectural changes needed
- Use case unclear

**Security Scanning**
- Would require third-party tools
- Out of current scope
- CI/CD could add this

**Performance Metrics**
- Needs telemetry infrastructure
- Low priority currently

### Roadmap Ideas

- Plugin system for extensibility
- Multi-language support
- Custom base image support
- Advanced container networking
- Volume mount customization

## Contributing

### Pull Request Process

1. Fork repository
2. Create feature branch
3. Add tests for changes
4. Update documentation
5. Run integration tests
6. Submit PR with description

### Code Review Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] Backward compatible
- [ ] Security reviewed
- [ ] Performance impact assessed

## References

### External Documentation

- [Docker Documentation](https://docs.docker.com/)
- [Docker BuildKit](https://docs.docker.com/build/buildx/)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide)
- [Semantic Versioning](https://semver.org/)

### Internal Documentation

- README.md - User documentation
- EXAMPLES.md - Usage patterns
- CHANGELOG.md - Version history
- .codex_yolo.conf.example - Configuration reference

## Version History

### v1.1.0 (2026-01-31)

**Major Features**:
- Health check and diagnostics system
- Configuration file support (3 locations)
- Version commands
- Verbose mode
- Shell completion (bash/zsh)
- Comprehensive test suite
- CI/CD pipeline

**Technical Changes**:
- Structured logging framework
- Enhanced auto-update (optional files)
- Config priority system
- Improved code organization
- Integration test infrastructure

**Impact**: +1,800 lines of code, +186% files, 14 automated tests

### v1.0.2 (Previous)

Basic functionality with auto-update and Docker containerization.

---

**Document Version**: 1.1.0  
**Last Updated**: 2026-01-31  
**Maintained By**: Development Team
