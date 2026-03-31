#!/usr/bin/env bash
set -euo pipefail

# OpenCode Installer
# This script installs OpenCode to ~/.opencode-container/ with symlinks to ~/.local/bin/ and ~/.config/zsh/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
STATE_DIR="${HOME}/.opencode-container"
LOCAL_BIN_DIR="${HOME}/.local/bin"
ZSH_COMPLETIONS_DIR="${HOME}/.config/zsh/completions.d"

# Color codes
C_RESET=""
C_BOLD=""
C_DIM=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_MAGENTA=""
C_CYAN=""

# Initialize colors if terminal supports them
init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_MAGENTA='\033[35m'
    C_CYAN='\033[36m'
  fi
}

# Logging functions
log_info() {
  printf "%b[info]%b %s\n" "$C_CYAN" "$C_RESET" "$*"
}

log_warn() {
  printf "%b[warn]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"
}

log_ok() {
  printf "%b[ ok ]%b %s\n" "$C_GREEN" "$C_RESET" "$*"
}

log_step() {
  printf "%b==>%b %s\n" "$C_MAGENTA" "$C_RESET" "$*"
}

die() {
  printf "%bError:%b %s\n" "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

# Prompt user for yes/no confirmation
prompt_yn() {
  local prompt="$1"
  local response
  read -p "$(printf "%b%s (y/n) %b" "$C_BOLD" "$prompt" "$C_RESET")" -n 1 -r response
  echo
  [[ "$response" =~ ^[Yy]$ ]]
}

# Check if podman or docker is available
check_dependencies() {
  log_step "Checking dependencies"
  
  if command -v podman >/dev/null 2>&1; then
    log_ok "podman found: $(podman --version)"
    return 0
  elif command -v docker >/dev/null 2>&1; then
    log_ok "docker found: $(docker --version)"
    return 0
  else
    log_warn "Neither podman nor docker found!"
    cat << 'EOF'

Install podman with:
  Ubuntu/Debian:     sudo apt-get install -y podman
  Fedora/RHEL:       sudo dnf install -y podman
  Arch:              sudo pacman -S podman
  macOS:             brew install podman
                     or download Podman Desktop: https://podman.io/getting-started/installation
  Other:             https://podman.io/getting-started/installation

EOF
    if ! prompt_yn "Continue without podman/docker?"; then
      log_warn "Installation cancelled."
      exit 0
    fi
  fi
}

# Create necessary directories
create_directories() {
  log_step "Creating directories"
  
  mkdir -p "$STATE_DIR/bin" || die "Failed to create $STATE_DIR/bin"
  log_ok "Created $STATE_DIR/bin"
  
  mkdir -p "$STATE_DIR/completion" || die "Failed to create $STATE_DIR/completion"
  log_ok "Created $STATE_DIR/completion"
  
  mkdir -p "$STATE_DIR/container" || die "Failed to create $STATE_DIR/container"
  log_ok "Created $STATE_DIR/container"
  
  mkdir -p "$STATE_DIR/config/git" || die "Failed to create $STATE_DIR/config/git"
  log_ok "Created $STATE_DIR/config/git"
  
  mkdir -p "$STATE_DIR/config/opencode" || die "Failed to create $STATE_DIR/config/opencode"
  log_ok "Created $STATE_DIR/config/opencode"
  
  mkdir -p "$LOCAL_BIN_DIR" || die "Failed to create $LOCAL_BIN_DIR"
  log_ok "Created $LOCAL_BIN_DIR"
  
  mkdir -p "$ZSH_COMPLETIONS_DIR" || die "Failed to create $ZSH_COMPLETIONS_DIR"
  log_ok "Created $ZSH_COMPLETIONS_DIR"
}

# Display what will be copied
show_copy_plan() {
  log_step "Files to be installed"
  cat << 'EOF'
  - script/opencode.sh              → ~/.opencode-container/bin/opencode.sh
  - script/_opencode                → ~/.opencode-container/completion/_opencode.zsh
  - container/Containerfile         → ~/.opencode-container/container/Containerfile
  - config/git/config               → ~/.opencode-container/config/git/config
  - config/opencode/AGENTS.md       → ~/.opencode-container/config/opencode/AGENTS.md
  - config/opencode/opencode.jsonc  → ~/.opencode-container/config/opencode/opencode.jsonc
  - config/opencode/tui.jsonc       → ~/.opencode-container/config/opencode/tui.jsonc

Symlinks created:
  - ~/.local/bin/opencode           → ~/.opencode-container/bin/opencode.sh
  - ~/.config/zsh/completions.d/_opencode → ~/.opencode-container/completion/_opencode.zsh

EOF
}

# Copy files with smart config handling
copy_files() {
  log_step "Copying files"
  
  # Copy opencode.sh
  if [[ -f "$SCRIPT_DIR/script/opencode.sh" ]]; then
    cp "$SCRIPT_DIR/script/opencode.sh" "$STATE_DIR/bin/opencode.sh" || die "Failed to copy opencode.sh"
    chmod +x "$STATE_DIR/bin/opencode.sh"
    log_ok "Installed opencode.sh"
  else
    die "script/opencode.sh not found in $SCRIPT_DIR"
  fi
  
  # Copy zsh completion
  if [[ -f "$SCRIPT_DIR/script/_opencode" ]]; then
    cp "$SCRIPT_DIR/script/_opencode" "$STATE_DIR/completion/_opencode.zsh" || die "Failed to copy _opencode"
    chmod +x "$STATE_DIR/completion/_opencode.zsh"
    log_ok "Installed zsh completion"
  else
    die "script/_opencode not found in $SCRIPT_DIR"
  fi
  
  # Copy Containerfile
  if [[ -f "$SCRIPT_DIR/container/Containerfile" ]]; then
    cp "$SCRIPT_DIR/container/Containerfile" "$STATE_DIR/container/Containerfile" || die "Failed to copy Containerfile"
    log_ok "Installed Containerfile"
  else
    die "container/Containerfile not found in $SCRIPT_DIR"
  fi
  
  # Copy config files (only if they don't exist - protect user customizations)
  if [[ ! -f "$STATE_DIR/config/git/config" ]]; then
    if [[ -f "$SCRIPT_DIR/config/git/config" ]]; then
      cp "$SCRIPT_DIR/config/git/config" "$STATE_DIR/config/git/config" || die "Failed to copy git config"
      log_ok "Installed git config"
    fi
  else
    log_info "Skipping git config (already exists, customize as needed)"
  fi
  
  if [[ ! -f "$STATE_DIR/config/opencode/AGENTS.md" ]]; then
    if [[ -f "$SCRIPT_DIR/config/opencode/AGENTS.md" ]]; then
      cp "$SCRIPT_DIR/config/opencode/AGENTS.md" "$STATE_DIR/config/opencode/AGENTS.md" || die "Failed to copy AGENTS.md"
      log_ok "Installed AGENTS.md"
    fi
  else
    log_info "Skipping AGENTS.md (already exists)"
  fi
  
  if [[ ! -f "$STATE_DIR/config/opencode/opencode.jsonc" ]]; then
    if [[ -f "$SCRIPT_DIR/config/opencode/opencode.jsonc" ]]; then
      cp "$SCRIPT_DIR/config/opencode/opencode.jsonc" "$STATE_DIR/config/opencode/opencode.jsonc" || die "Failed to copy opencode.jsonc"
      log_ok "Installed opencode.jsonc"
    fi
  else
    log_info "Skipping opencode.jsonc (already exists)"
  fi
  
  if [[ ! -f "$STATE_DIR/config/opencode/tui.jsonc" ]]; then
    if [[ -f "$SCRIPT_DIR/config/opencode/tui.jsonc" ]]; then
      cp "$SCRIPT_DIR/config/opencode/tui.jsonc" "$STATE_DIR/config/opencode/tui.jsonc" || die "Failed to copy tui.jsonc"
      log_ok "Installed tui.jsonc"
    fi
  else
    log_info "Skipping tui.jsonc (already exists)"
  fi
}

# Create symlinks
create_symlinks() {
  log_step "Creating symlinks"
  
  # Remove existing symlinks if they exist
  if [[ -L "$LOCAL_BIN_DIR/opencode" ]]; then
    rm "$LOCAL_BIN_DIR/opencode" || die "Failed to remove existing symlink $LOCAL_BIN_DIR/opencode"
  fi
  
  if [[ -L "$ZSH_COMPLETIONS_DIR/_opencode" ]]; then
    rm "$ZSH_COMPLETIONS_DIR/_opencode" || die "Failed to remove existing symlink $ZSH_COMPLETIONS_DIR/_opencode"
  fi
  
  # Create new symlinks
  ln -s "$STATE_DIR/bin/opencode.sh" "$LOCAL_BIN_DIR/opencode" || die "Failed to create symlink for opencode"
  log_ok "Created ~/.local/bin/opencode"
  
  ln -s "$STATE_DIR/completion/_opencode.zsh" "$ZSH_COMPLETIONS_DIR/_opencode" || die "Failed to create symlink for completion"
  log_ok "Created ~/.config/zsh/completions.d/_opencode"
}

# Verify installation
verify_installation() {
  log_step "Verifying installation"
  
  local all_ok=true
  
  if [[ ! -x "$STATE_DIR/bin/opencode.sh" ]]; then
    log_warn "opencode.sh not executable"
    all_ok=false
  else
    log_ok "opencode.sh is executable"
  fi
  
  if [[ ! -L "$LOCAL_BIN_DIR/opencode" ]]; then
    log_warn "symlink ~/.local/bin/opencode not found"
    all_ok=false
  else
    log_ok "symlink ~/.local/bin/opencode exists"
  fi
  
  if [[ ! -L "$ZSH_COMPLETIONS_DIR/_opencode" ]]; then
    log_warn "symlink ~/.config/zsh/completions.d/_opencode not found"
    all_ok=false
  else
    log_ok "symlink ~/.config/zsh/completions.d/_opencode exists"
  fi
  
  if [[ ! -d "$STATE_DIR/config/opencode" ]]; then
    log_warn "~/.opencode-container/config/opencode directory not found"
    all_ok=false
  else
    log_ok "config directory structure exists"
  fi
  
  if [[ ! -d "$STATE_DIR/config/git" ]]; then
    log_warn "~/.opencode-container/config/git directory not found"
    all_ok=false
  else
    log_ok "git config directory exists"
  fi
  
  if [[ "$all_ok" != "true" ]]; then
    die "Verification failed - some components are missing"
  fi
}

# Installation main
install_main() {
  init_colors
  
  log_step "OpenCode Installation"
  printf "%b\nThis will install OpenCode to:  %s\n\n" "$C_DIM" "$STATE_DIR" "$C_RESET"
  
  check_dependencies
  
  show_copy_plan
  
  if ! prompt_yn "Proceed with installation?"; then
    log_warn "Installation cancelled."
    exit 0
  fi
  
  create_directories
  copy_files
  create_symlinks
  verify_installation
  
  printf "\n"
  log_ok "Installation complete!"
  
  cat << EOF

${C_BOLD}Next steps:${C_RESET}
  1. Ensure ~/.local/bin is in your PATH:
     echo \$PATH | grep ~/.local/bin
     
  2. If ~/.local/bin is not in PATH, add to your shell config:
     export PATH="\$HOME/.local/bin:\$PATH"
  
  3. Test the installation:
     ${C_BOLD}opencode --help${C_RESET}
     ${C_BOLD}opencode status${C_RESET}
  
  4. Try running opencode in a directory:
     ${C_BOLD}cd ~/your/project${C_RESET}
     ${C_BOLD}opencode .${C_RESET}

${C_BOLD}For NixOS users:${C_RESET}
  See README-INSTALL.md for flake.nix integration

${C_BOLD}Uninstall:${C_RESET}
  ${C_BOLD}./install.sh uninstall${C_RESET}

EOF
}

# Uninstall main
uninstall_main() {
  init_colors
  
  log_step "OpenCode Uninstallation"
  printf "\n%bThis will remove:%b\n" "$C_BOLD" "$C_RESET"
  printf "  - ~/.local/bin/opencode (symlink)\n"
  printf "  - ~/.config/zsh/completions.d/_opencode (symlink)\n"
  printf "  - Optionally: ~/.opencode-container/ (with all user data)\n\n"
  
  if ! prompt_yn "Continue with uninstallation?"; then
    log_warn "Uninstallation cancelled."
    exit 0
  fi
  
  log_step "Removing symlinks"
  
  if [[ -L "$LOCAL_BIN_DIR/opencode" ]]; then
    rm "$LOCAL_BIN_DIR/opencode" || die "Failed to remove $LOCAL_BIN_DIR/opencode"
    log_ok "Removed ~/.local/bin/opencode"
  else
    log_info "~/.local/bin/opencode not found (already removed?)"
  fi
  
  if [[ -L "$ZSH_COMPLETIONS_DIR/_opencode" ]]; then
    rm "$ZSH_COMPLETIONS_DIR/_opencode" || die "Failed to remove $ZSH_COMPLETIONS_DIR/_opencode"
    log_ok "Removed ~/.config/zsh/completions.d/_opencode"
  else
    log_info "~/.config/zsh/completions.d/_opencode not found (already removed?)"
  fi
  
  if prompt_yn "Remove ~/.opencode-container/ and all user data?"; then
    rm -rf "$STATE_DIR" || die "Failed to remove $STATE_DIR"
    log_ok "Removed ~/.opencode-container/"
  else
    log_info "Keeping ~/.opencode-container/ (you can manually remove it later)"
  fi
  
  printf "\n"
  log_ok "Uninstallation complete!"
}

# Main entry point
main() {
  init_colors
  
  case "${1:-install}" in
    uninstall)
      uninstall_main
      ;;
    install|"")
      install_main
      ;;
    help|--help|-h)
      cat << 'EOF'
OpenCode Installer

Usage:
  ./install.sh              Install OpenCode
  ./install.sh uninstall    Uninstall OpenCode
  ./install.sh help         Show this help message

Installation:
  The install command will:
  1. Check for podman/docker (warn if missing)
  2. Create ~/.opencode-container/ directory structure
  3. Copy OpenCode files to ~/.opencode-container/
  4. Create symlinks in ~/.local/bin/ and ~/.config/zsh/completions.d/
  5. Verify all components are in place

Uninstallation:
  The uninstall command will:
  1. Remove symlinks from ~/.local/bin/ and ~/.config/zsh/completions.d/
  2. Optionally remove ~/.opencode-container/ and all user data

Configuration:
  After installation, config files can be customized at:
  ~/.opencode-container/config/

For more information, see README-INSTALL.md
EOF
      ;;
    *)
      printf "%bUnknown option: %s%b\n" "$C_RED" "$1" "$C_RESET" >&2
      printf "Use './install.sh help' for usage information\n"
      exit 1
      ;;
  esac
}

main "$@"
