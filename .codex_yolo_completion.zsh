#compdef codex_yolo
# Zsh completion for codex_yolo

_codex_yolo() {
  local -a codex_yolo_commands codex_yolo_flags codex_commands

  codex_yolo_commands=(
    'diagnostics:Run health checks and show diagnostic information'
    'doctor:Alias for diagnostics'
    'health:Alias for diagnostics'
    'version:Show version information'
    'login:Log in to OpenAI Codex'
  )

  codex_yolo_flags=(
    '--version[Show version and exit]'
    '--verbose[Enable verbose output]'
    '-v[Enable verbose output]'
    '--pull[Pull base image before building]'
    '--gh[Mount host ~/.copilot after verifying host gh auth]'
    '--help[Show help information]'
  )

  codex_commands=(
    '--yolo[Enable YOLO mode (automatic execution)]'
    '--search[Enable search mode]'
    '--device-auth[Use device authentication flow]'
  )

  _arguments -C \
    '1: :->command' \
    '*:: :->args' \
    && return 0

  case $state in
    command)
      _describe -t codex_yolo_commands 'codex_yolo commands' codex_yolo_commands
      _describe -t codex_yolo_flags 'codex_yolo flags' codex_yolo_flags
      _describe -t codex_commands 'codex commands' codex_commands
      ;;
    args)
      case $line[1] in
        login)
          _arguments '--device-auth[Use device authentication]'
          ;;
      esac
      ;;
  esac

  return 0
}

_codex_yolo "$@"
