#!/usr/bin/env sh

# Host CLI is CodeBuddy. Resolution order:
#   1) CODEBUDDY_CONFIG_DIR (explicit override)
#   2) ~/.codebuddy default
resolve_codebuddy_config_dir() {
  configured="${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"
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
