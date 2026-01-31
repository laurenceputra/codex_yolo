# Quick Reference: v1.1.0 Changes

## What Changed?

Version 1.1.0 adds major improvements while maintaining full backward compatibility.

## Your Questions Answered

### Q: "What's the full extent of changes?"
**A:** See [EXPLANATION.md](EXPLANATION.md) for comprehensive details. Brief summary:
- **10 new files**: diagnostics, completion scripts, examples, tests, CI/CD, docs
- **4 modified files**: main script, install script, README, VERSION
- **~1,800 lines added**: Tests, documentation, features
- **Zero breaking changes**: All v1.0.x functionality preserved

### Q: "Are changes documented in the README?"
**A:** Yes! The README now has:
- **"What's New in v1.1.0"** section at the top
- **Migration Guide** with upgrade instructions
- **Enhanced Configuration** documentation
- Examples for all new features

### Q: "Can older versions download all files?"
**A:** Mostly yes:
- **Core files**: Auto-downloaded by v1.0.x ✅
- **Optional files**: Need one of:
  - Second run (after auto-update to v1.1.0)
  - Manual re-install: `curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh | bash`
- **No breaking changes**: Everything still works ✅

### Q: "Can config be in installation directory?"
**A:** Yes! Three locations supported (in precedence order):
```
1. ${INSTALL_DIR}/config          (e.g., ~/.codex_yolo/config)
2. ~/.codex_yolo/config           (alternative location)  
3. ~/.codex_yolo.conf             (traditional location)
4. Environment variables          (highest priority)
```

## New Features Quick Start

### Diagnostics
```bash
codex_yolo diagnostics  # Check your system
codex_yolo doctor       # Same thing
```

### Version Info
```bash
codex_yolo version      # Show version number
codex_yolo --version    # Show with label
```

### Verbose Mode
```bash
codex_yolo --verbose    # See what's happening
CODEX_VERBOSE=1 codex_yolo
```

### Configuration
Create `~/.codex_yolo.conf`:
```bash
CODEX_VERBOSE=1
CODEX_BASE_IMAGE=node:20-slim
```

Or in your install directory:
```bash
echo 'CODEX_VERBOSE=1' > ~/.codex_yolo/config
```

### Shell Completion
```bash
# Bash
source ~/.codex_yolo/.codex_yolo_completion.bash

# Zsh
source ~/.codex_yolo/.codex_yolo_completion.zsh
```

## Upgrading from v1.0.x

### Automatic (Just Run It)
```bash
codex_yolo
# First run: Updates core files to v1.1.0
# Second run: Downloads optional files
```

### Manual (Get Everything Now)
```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/codex_yolo/main/install.sh | bash
```

## Documentation

- **README.md** - Main documentation (updated)
- **EXAMPLES.md** - Usage examples and best practices (new)
- **CHANGELOG.md** - Version history (new)
- **EXPLANATION.md** - Comprehensive technical details (new)
- **.codex_yolo.conf.example** - Configuration template (new)

## Testing

Run the test suite:
```bash
~/.codex_yolo/tests/integration_tests.sh
```

All 14 tests should pass.

## Getting Help

```bash
codex_yolo diagnostics  # System check
codex_yolo --help       # Codex CLI help
```

## Key Points

✅ **Backward Compatible**: All v1.0.x scripts work  
✅ **Safe to Update**: No breaking changes  
✅ **Auto-Update**: Happens automatically  
✅ **Well Tested**: 14 integration tests  
✅ **Documented**: Complete docs in README

## Need More Info?

- **Basic usage**: See README.md
- **Examples**: See EXAMPLES.md
- **Technical details**: See EXPLANATION.md
- **Changes**: See CHANGELOG.md
