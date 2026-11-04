#!/usr/bin/env sh

# omc adaptation: host CLI is CodeBuddy. Resolution order:
#   1) CODEBUDDY_CONFIG_DIR (CodeBuddy-native)
#   2) CLAUDE_CONFIG_DIR (legacy/Claude Code compat)
#   3) ~/.codebuddy default
resolve_claude_config_dir() {
  configured="${CODEBUDDY_CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.codebuddy}}"
  configured="${configured#${configured%%[![:space:]]*}}"
  configured="${configured%${configured##*[![:space:]]}}"
  if [ "$configured" != "/" ]; then
    configured="${configured%/}"
  fi
  case "$configured" in
    \~)
      printf '%s\n' "$HOME"
      ;;
    \~/*)
      configured="${configured#\~/}"
      printf '%s/%s\n' "$HOME" "$configured"
      ;;
    \~\\*)
      configured="${configured#\~}"
      configured="${configured#\\}"
      printf '%s/%s\n' "$HOME" "$configured"
      ;;
    *)
      printf '%s\n' "$configured"
      ;;
  esac
}
