#!/bin/bash
# OpenCode Git Configuration Validation Script
# This script runs on container startup to ensure git identity is properly
# configured. It auto-detects and uses the host git configuration if available,
# with graceful fallback to template defaults.

set -euo pipefail

# Color codes for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RESET='\033[0m'

# Paths
readonly HOST_GIT_CONFIG_XDG="/root/.config.host/git/config"
readonly HOST_GIT_CONFIG_LEGACY="/root/.config.host/.gitconfig"
readonly CONTAINER_GIT_CONFIG="/root/.config/git/config"
readonly GIT_CONFIG_DIR="/root/.config/git"

# Logging functions
log_info() {
  printf "%b[info]%b %s\n" "$BLUE" "$RESET" "$*"
}

log_ok() {
  printf "%b[ok]%b %s\n" "$GREEN" "$RESET" "$*"
}

log_warn() {
  printf "%b[warn]%b %s\n" "$YELLOW" "$RESET" "$*"
}

# Detect and configure git identity
detect_git_identity() {
  local name email config_source

  # Priority 1: Check for host-provided config files
  # Standard: XDG Base Directory Specification (~/.config/git/config)
  # Legacy: ~/.gitconfig for backward compatibility
  if [[ -f "$HOST_GIT_CONFIG_XDG" ]]; then
    config_source="$HOST_GIT_CONFIG_XDG"
    log_info "Found host git config at ~/.config/git/config"
  elif [[ -f "$HOST_GIT_CONFIG_LEGACY" ]]; then
    config_source="$HOST_GIT_CONFIG_LEGACY"
    log_info "Found host git config at ~/.gitconfig"
  fi

  if [[ -n "$config_source" ]]; then
    log_info "Loading git config from host..."
    mkdir -p "$GIT_CONFIG_DIR"
    cp "$config_source" "$CONTAINER_GIT_CONFIG"

    # Verify it worked
    name=$(git config user.name 2>/dev/null || echo "")
    email=$(git config user.email 2>/dev/null || echo "")

    if [[ -n "$name" && -n "$email" ]]; then
      log_ok "Git identity from host: $name <$email>"
      return 0
    fi
  fi

  # Priority 2: Check if git is already configured in container
  # (This only applies if no host config was found)
  name=$(git config user.name 2>/dev/null || echo "")
  email=$(git config user.email 2>/dev/null || echo "")

  if [[ -n "$name" && -n "$email" ]]; then
    log_ok "Git identity detected: $name <$email>"
    return 0
  fi

  # Priority 3: Check environment variable overrides
  name="${GIT_AUTHOR_NAME:-}"
  email="${GIT_AUTHOR_EMAIL:-}"

  if [[ -n "$name" && -n "$email" ]]; then
    log_info "Using identity from GIT_AUTHOR_* environment variables"
    git config --global user.name "$name"
    git config --global user.email "$email"
    log_ok "Git identity configured: $name <$email>"
    return 0
  fi

  # Priority 4: Fallback to template defaults
  log_warn "No git identity configured, using fallback..."
  name="TobsenCode"
  email="tobias@opencode.dev"
  log_warn "Using template fallback identity: $name <$email>"

  git config --global user.name "$name"
  git config --global user.email "$email"

  log_info "To use your personal git identity in containers, configure git on the host:"
  log_info "  git config --global user.name 'Your Name'"
  log_info "  git config --global user.email 'your@email.com'"
  log_info ""
  log_info "Or pass environment variables when running opencode:"
  log_info "  GIT_AUTHOR_NAME='Your Name' GIT_AUTHOR_EMAIL='your@email.com' opencode ."
}

# Main entry point
main() {
  log_info "Validating OpenCode container environment..."
  detect_git_identity
  log_info "Passing control to opencode..."
  exec "$@"
}

main "$@"
