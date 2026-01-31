# codex_yolo Examples and Use Cases

This guide provides practical examples for using codex_yolo effectively.

## Getting Started

### First Run
```bash
# Start codex_yolo in your project directory
cd /path/to/your/project
codex_yolo
```

On first run, you'll be prompted to log in. Follow the authentication flow.

### Login Examples
```bash
# Standard login (opens browser)
codex_yolo login

# Device authentication (for remote/headless systems)
codex_yolo login --device-auth
```

## Common Use Cases

### 1. Code Review and Refactoring
```bash
# Ask Codex to review your current changes
cd your-repo
codex_yolo
# Then: "Review the changes in this branch and suggest improvements"
```

### 2. Bug Fixing
```bash
# Let Codex help debug and fix issues
codex_yolo
# Then: "There's a null pointer error in the authentication module. Help me fix it."
```

### 3. Adding New Features
```bash
# Have Codex implement a feature
codex_yolo
# Then: "Add a new REST endpoint for user profile updates with validation"
```

### 4. Writing Tests
```bash
# Generate test cases
codex_yolo
# Then: "Write unit tests for the user authentication service"
```

### 5. Documentation
```bash
# Generate or improve documentation
codex_yolo
# Then: "Add JSDoc comments to all functions in src/utils.js"
```

## Advanced Usage

### Using Configuration Files
Create `~/.codex_yolo/config` to set persistent preferences:
```bash
# Example configuration
echo 'CODEX_VERBOSE=1' > ~/.codex_yolo/config
echo 'CODEX_SKIP_UPDATE_CHECK=0' >> ~/.codex_yolo/config
```

### Verbose Mode
Get detailed information about what codex_yolo is doing:
```bash
codex_yolo --verbose
# or
CODEX_VERBOSE=1 codex_yolo
```

### Force Update/Rebuild
```bash
# Force pull base image and rebuild
codex_yolo --pull

# Force rebuild without cache
CODEX_BUILD_NO_CACHE=1 codex_yolo

# Both together
CODEX_BUILD_NO_CACHE=1 codex_yolo --pull
```

### Dry Run
Preview Docker commands without executing:
```bash
CODEX_DRY_RUN=1 codex_yolo
```

### Skip Automatic Updates
```bash
# Skip checking for codex_yolo updates
CODEX_SKIP_UPDATE_CHECK=1 codex_yolo

# Skip checking for Codex CLI version updates
CODEX_SKIP_VERSION_CHECK=1 codex_yolo
```

## Diagnostics and Troubleshooting

### Check System Health
```bash
# Run diagnostics to check configuration
codex_yolo diagnostics
# or
codex_yolo doctor
```

### Version Information
```bash
# Show codex_yolo version
codex_yolo version
# or
codex_yolo --version
```

### Common Issues

#### "Docker daemon not running"
```bash
# Check Docker status
docker info

# Start Docker (varies by system)
# macOS: Start Docker Desktop
# Linux: sudo systemctl start docker
```

#### "Permission denied" errors
```bash
# Check workspace permissions
ls -la

# Ensure .codex directory is writable
chmod 755 ~/.codex
```

#### Image build failures
```bash
# Run diagnostics
codex_yolo diagnostics

# Try rebuilding without cache
CODEX_BUILD_NO_CACHE=1 codex_yolo --pull
```

## Best Practices

### 1. Run from Repository Root
Always run codex_yolo from your repository's root directory:
```bash
cd /path/to/repo
codex_yolo
```

### 2. Use Git Configuration
Ensure your Git identity is configured for proper commit attribution:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. Review Changes Before Committing
Codex runs in `--yolo` mode but always review generated changes:
```bash
# After Codex makes changes
git diff
git status
```

### 4. Start with Clear Instructions
Be specific about what you want Codex to do:
- ✅ "Add input validation to the login form with email and password checks"
- ❌ "Fix the form"

### 5. Iterative Development
Work in small iterations:
1. Ask Codex to make a specific change
2. Review the change
3. Test the change
4. Iterate if needed

## Integration Examples

### CI/CD Pipeline
```bash
# Use in CI with device auth
CODEX_SKIP_UPDATE_CHECK=1 codex_yolo login --device-auth
codex_yolo "Run all tests and fix any failures"
```

### Pre-commit Hooks
```bash
# Add to .git/hooks/pre-commit
#!/bin/bash
codex_yolo "Review and format staged changes"
```

### Custom Scripts
```bash
#!/bin/bash
# automated-refactor.sh

export CODEX_VERBOSE=1
export CODEX_SKIP_UPDATE_CHECK=1

cd "$PROJECT_DIR"
codex_yolo "Refactor all TypeScript files to use strict mode"
```

## Environment Variables Reference

Quick reference for all configuration options:

```bash
# Core settings
CODEX_BASE_IMAGE=node:20-slim
CODEX_YOLO_IMAGE=codex-cli-yolo:local
CODEX_YOLO_HOME=/home/codex
CODEX_YOLO_WORKDIR=/workspace

# Repository settings
CODEX_YOLO_REPO=laurenceputra/codex_yolo
CODEX_YOLO_BRANCH=main

# Behavior flags
CODEX_YOLO_CLEANUP=1
CODEX_SKIP_UPDATE_CHECK=0
CODEX_SKIP_VERSION_CHECK=0
CODEX_BUILD_NO_CACHE=0
CODEX_BUILD_PULL=0
CODEX_DRY_RUN=0
CODEX_VERBOSE=0
```

## Tips and Tricks

### Faster Subsequent Runs
The Docker image is cached after first build, making subsequent runs fast.

### Multiple Projects
You can use codex_yolo in multiple projects simultaneously - just run it from different directories.

### Offline Mode
Once the image is built, you can use codex_yolo offline (though authentication requires internet).

### Custom Base Images
```bash
# Use a different Node.js version
CODEX_BASE_IMAGE=node:18-slim codex_yolo
```

## Getting Help

- Run `codex_yolo --help` for Codex CLI help
- Run `codex_yolo diagnostics` for system health check  
- Visit: https://github.com/laurenceputra/codex_yolo
- Report issues: https://github.com/laurenceputra/codex_yolo/issues
