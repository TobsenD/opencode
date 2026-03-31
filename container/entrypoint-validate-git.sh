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
readonly HOST_GIT_CONFIG="/root/.config.host/git/config"
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
  # Check if git is already configured
  local name email
  name=$(git config user.name 2>/dev/null || echo "")
  email=$(git config user.email 2>/dev/null || echo "")

  if [[ -n "$name" && -n "$email" ]]; then
    log_ok "Git identity detected: $name <$email>"
    return 0
  fi

  # Try to load from host config
  if [[ -f "$HOST_GIT_CONFIG" ]]; then
    log_info "Loading git config from host..."
    mkdir -p "$GIT_CONFIG_DIR"
    cp "$HOST_GIT_CONFIG" "$CONTAINER_GIT_CONFIG"

    # Verify it worked
    name=$(git config user.name 2>/dev/null || echo "")
    email=$(git config user.email 2>/dev/null || echo "")

    if [[ -n "$name" && -n "$email" ]]; then
      log_ok "Git identity from host: $name <$email>"
      return 0
    fi
  fi

  # Fallback: use template defaults or environment variables
  log_warn "No git identity configured, using fallback..."

  # Check environment variable overrides first
  name="${GIT_AUTHOR_NAME:-TobsenCode}"
  email="${GIT_AUTHOR_EMAIL:-tobias@opencode.dev}"

  git config --global user.name "$name"
  git config --global user.email "$email"

  log_warn "Using fallback identity: $name <$email>"
  log_info "To use your personal git identity in containers, configure git on the host:"
  log_info "  git config --global user.name 'Your Name'"
  log_info "  git config --global user.email 'your@email.com'"
}

# Main entry point
main() {
  log_info "Validating OpenCode container environment..."
  detect_git_identity
  log_info "Passing control to opencode..."
  exec "$@"
}

main "$@"
