# Bash completion for codex_yolo
# Source this file or add it to your bash completion directory

_codex_yolo_complete() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # codex_yolo specific commands and flags
  local codex_yolo_opts="diagnostics doctor health version --version --verbose -v --pull --gh --help"
  
  # Common codex CLI commands (pass-through)
  local codex_opts="login --help --yolo --search --device-auth"

  # Combine all options
  opts="${codex_yolo_opts} ${codex_opts}"

  # If we're completing the first argument after codex_yolo
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
  fi

  # Default to no completion for other positions
  COMPREPLY=()
  return 0
}

complete -F _codex_yolo_complete codex_yolo
