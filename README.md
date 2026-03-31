# OpenCode Installation Guide

This guide covers all methods to install OpenCode, a container-based development environment wrapper that uses podman/docker to provide an isolated, reproducible workspace.

> **About This Project**  
> This is a container wrapper and installation toolkit for [OpenCode](https://github.com/anomalyco/opencode). It provides enhanced installation methods (Bash, Nix flake, home-manager, nixos-rebuild) for the original OpenCode project. All credit for the core OpenCode functionality goes to the original authors at https://github.com/anomalyco/opencode.

## Installation Overview

OpenCode can be installed using:
**Bash Installer** (`install.sh`) - For all platforms

## What Gets Installed

```
~/.local/bin/opencode                          # Executable (symlink)
~/.config/zsh/completions.d/_opencode          # Zsh completion (symlink)
~/.opencode-container/                         # Installation root
├── bin/opencode.sh                            # Main script
├── completion/_opencode.zsh                   # Completion script
├── container/Containerfile                    # Container definition
└── config/
    ├── git/config                             # Git config template
    └── opencode/
        ├── AGENTS.md                          # Agent instructions
        ├── opencode.jsonc                     # App configuration
        └── tui.jsonc                          # UI configuration
```

## Prerequisites

- **Linux, macOS, or WSL2**
- **podman** or **docker** (the installer will warn if missing and provide install instructions)
- **Bash** 4.0+
- **zsh** (for shell completion)

## Method 1: Bash Installer (Recommended for Most Users)

### Quick Install

```bash
git clone https://github.com/TobsenD/opencode.git
cd opencode
./install.sh
```

### Remote Install (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/TobsenD/opencode/main/install.sh | bash
```

### What It Does

The installer will:

1. ✅ Check for podman/docker (warn if missing with install instructions)
2. ✅ Create `~/.opencode-container/` and all subdirectories
3. ✅ Copy OpenCode files to `~/.opencode-container/`
4. ✅ Copy config templates (only if they don't exist - safe for re-runs)
5. ✅ Create symlinks in `~/.local/bin/` and `~/.config/zsh/completions.d/`
6. ✅ Verify all components are installed correctly

### Interactive Prompts

The installer is interactive and will show you:
- What files will be installed
- Confirmation before proceeding
- Real-time installation progress
- Next steps after completion

### Example Installation Session

```
==> OpenCode Installation
[info] This will install OpenCode to:  /home/user/.opencode-container/

==> Checking dependencies
[ok] podman found: podman version 4.5.0

==> Files to be installed
  - script/opencode.sh              → ~/.opencode-container/bin/opencode.sh
  - completion/_opencode.zsh        → ~/.opencode-container/completion/_opencode.zsh
  - container/Containerfile         → ~/.opencode-container/container/Containerfile
  ...

Proceed with installation? (y/n) y

==> Creating directories
[ok] Created ~/.opencode-container/bin

...

[ ok ] Installation complete!

Next steps:
  1. Ensure ~/.local/bin is in your PATH
  2. Test: opencode --help
  3. Try: opencode status
  4. Run: opencode .
```

### Ensure PATH Includes ~/.local/bin

After installation, make sure `~/.local/bin` is in your `PATH`:

```bash
echo $PATH | grep ~/.local/bin
```

If not present, add to your shell config (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/config.fish`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.bashrc  # or ~/.zshrc, etc.
```

### Uninstall

To remove OpenCode:

```bash
./install.sh uninstall
```

The uninstaller will:
- Remove symlinks from `~/.local/bin/` and `~/.config/zsh/completions.d/`
- Ask if you want to remove `~/.opencode-container/` (keeping it lets you preserve user data and configs)

## First Time Usage

After installation with any method, verify it works:

```bash
# Show help
opencode --help

# Check for running containers
opencode status

# Run opencode in current directory
cd ~/your/project
opencode .

# Or enter a shell
opencode shell ~/your/project
```

## Post-Installation

### 1. Customize Configuration (Optional)

Edit config files in `~/.opencode-container/config/`:

- `git/config` - Git configuration for containers
- `opencode/opencode.jsonc` - OpenCode app configuration
- `opencode/tui.jsonc` - TUI theme settings
- `opencode/AGENTS.md` - Agent behavior guidelines

### 2. Verify Zsh Completion

In a new zsh shell:

```bash
opencode <TAB>
```

You should see available commands.

### 3. PATH Setup (if needed)

Verify `~/.local/bin` is in your PATH for all shells:

```bash
# Bash/Zsh (~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"

# Fish (~/.config/fish/config.fish)
fish_add_path $HOME/.local/bin
```

## Troubleshooting

### "opencode: command not found"

**Solution:** Ensure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
# Add to ~/.bashrc or ~/.zshrc to make permanent
```

Then reload your shell:

```bash
source ~/.bashrc  # or ~/.zshrc
```

### "podman: command not found"

**Solution:** Install podman:

```bash
# Ubuntu/Debian
sudo apt-get install -y podman

# Fedora/RHEL
sudo dnf install -y podman

# Arch
sudo pacman -S podman

# macOS
brew install podman
# or download Podman Desktop: https://podman.io/getting-started/installation
```

Then re-run the installer:

```bash
./install.sh
```

### "Cannot create symlink: File exists"

**Solution:** The symlink or file already exists. You can:

1. Manually remove it: `rm ~/.local/bin/opencode`
2. Re-run the installer: `./install.sh` (it will prompt you)

### Zsh Completion Not Working

**Solution:** Ensure `~/.config/zsh/completions.d/` is in your `fpath`:

Add to `~/.zshrc`:

```bash
fpath=(~/.config/zsh/completions.d $fpath)
autoload -Uz compinit && compinit
```

Then reload:

```bash
source ~/.zshrc
```

### "install.sh: Permission denied"

**Solution:** Make the installer executable:

```bash
chmod +x install.sh
./install.sh
```

## Updating OpenCode

### With Bash Installer

```bash
cd opencode  # where you cloned it
git pull
./install.sh  # Re-run installer (config files are preserved)
```

### With NixOS Flake

```bash
nix flake update
nix profile upgrade opencode  # or
home-manager switch           # if using home-manager
```

## Uninstalling OpenCode

### Method 1: Bash Installer

```bash
./install.sh uninstall
```

This will:
- Remove symlinks
- Ask if you want to remove `~/.opencode-container/`
- Preserve user data if you choose

## Directory Structure Reference

After installation, your directories will look like:

```
~/.local/bin/
└── opencode → ~/.opencode-container/bin/opencode.sh

~/.config/zsh/completions.d/
└── _opencode → ~/.opencode-container/completion/_opencode.zsh

~/.opencode-container/
├── bin/
│   └── opencode.sh                 (executable copy)
├── completion/
│   └── _opencode.zsh               (zsh completion)
├── container/
│   └── Containerfile               (container definition)
├── config/
│   ├── git/
│   │   └── config                  (git template - edit to customize)
│   └── opencode/
│       ├── AGENTS.md               (agent instructions - edit to customize)
│       ├── opencode.jsonc          (app config - edit to customize)
│       └── tui.jsonc               (ui config - edit to customize)
├── opencode/                       (created on first container run)
└── local/                          (created on first container run)
```

## Quick Reference

| Action | Command |
|--------|---------|
| Install | `./install.sh` |
| Uninstall | `./install.sh uninstall` |
| Help | `./install.sh help` or `opencode --help` |
| Run OpenCode | `opencode .` |
| Interactive shell | `opencode shell .` |
| List containers | `opencode status` |
| Stop container | `opencode stop <container-id>` |
| Stop all | `opencode killall` |
| Rebuild image | `opencode rebuild` |

## Environment Variables

Control installer behavior with environment variables:

```bash
# Disable colored output
NO_COLOR=1 ./install.sh

# For scripting (non-interactive mode is not supported,
# but you can pipe 'yes' to auto-confirm)
yes | ./install.sh
```

## Security Considerations

- Config files in `~/.opencode-container/config/` are readable by your user
- Containers run with your user ID by default (not root)
- Volume mounts are marked with `:Z` for SELinux compatibility
- Review `container/Containerfile` before building custom images

## Support & Documentation

- **This Project (Container Wrapper & Installation Toolkit):** https://github.com/TobsenD/opencode
- **Original OpenCode Project:** https://github.com/anomalyco/opencode
- **Podman Docs:** https://docs.podman.io
- **Home-Manager Docs:** https://nix-community.github.io/home-manager/

## License

OpenCode is provided as-is. See LICENSE file in the repository for details.

This wrapper and installation toolkit respects the license of the original OpenCode project at https://github.com/anomalyco/opencode.
