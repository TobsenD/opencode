# OpenCode on NixOS - Complete Installation Guide

This guide covers all methods to install OpenCode on NixOS systems, from quick per-user installation to system-wide declarative configuration.

> **About This Project**  
> This is a container wrapper and installation toolkit for [OpenCode](https://github.com/anomalyco/opencode). It provides enhanced installation methods specifically for NixOS users. All credit for the core OpenCode functionality goes to the original authors at https://github.com/anomalyco/opencode.

## Installation Methods Overview

| Method | Scope | User | Setup | Use Case |
|--------|-------|------|-------|----------|
| **nix profile install** | Per-user | Non-root | Imperative | Quick testing, temporary use |
| **home-manager** | Per-user | Non-root | Declarative | Full user config management |
| **nixos-rebuild switch** | System-wide | root | Declarative | System packages, all users |

All methods install OpenCode to `~/.opencode-container/` with symlinks to `~/.local/bin/opencode`.

## Method 1: Quick Installation with nix profile (Imperative)

For a quick, per-user installation without modifying system configuration:

```bash
nix profile install github:TobsenD/opencode
```

This installs the `opencode` package to your profile and adds it to PATH.

### Verify Installation

```bash
opencode --help
opencode status
```

### Update

```bash
nix profile upgrade opencode
```

### Uninstall

```bash
nix profile remove opencode
```

---

## Method 2: Home-Manager Integration (Per-user, Declarative)

For users with a home-manager flake configuration.

### Step 1: Add OpenCode to Your Flake Inputs

Edit your home-manager `flake.nix`:

```nix
{
  description = "Home configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode.url = "github:TobsenD/opencode";
    # For local development:
    # opencode.url = "path:/path/to/local/opencode";
  };

  outputs = { self, nixpkgs, home-manager, opencode }:
    {
      homeConfigurations."user@hostname" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home.nix
          opencode.homeManagerModules.default
          {
            programs.opencode.enable = true;
          }
        ];
      };
    };
}
```

### Step 2: Enable in home.nix

```nix
{ config, pkgs, ... }:
{
  programs.opencode.enable = true;

  # Rest of your home configuration...
}
```

### Step 3: Apply Configuration

```bash
home-manager switch
```

### What Home-Manager Does

- Adds `opencode` to `PATH`
- Installs zsh completion files
- Creates `~/.opencode-container/` with config templates (preserving user customizations)
- Creates symlinks in `~/.local/bin/` and `~/.config/zsh/completions.d/`

### Update

```bash
nix flake update
home-manager switch
```

### Uninstall

Remove `programs.opencode.enable = true;` from your configuration and run:

```bash
home-manager switch
```

---

## Method 3: System-wide Installation with nixos-rebuild (Declarative)

For system-wide installation accessible to all users.

### Approach A: Inline Flake Configuration

Add OpenCode directly to your NixOS system flake.

#### Step 1: Update /etc/nixos/flake.nix

Add OpenCode to inputs:

```nix
{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    opencode.url = "github:TobsenD/opencode";
  };

  outputs = { self, nixpkgs, flake-utils, opencode }:
    {
      nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { 
          inherit opencode;
        };
        modules = [
          ./configuration.nix
        ];
      };
    };
}
```

#### Step 2: Update /etc/nixos/configuration.nix

Add OpenCode package:

```nix
{ config, pkgs, opencode, ... }:
{
  # Add OpenCode to system packages
  environment.systemPackages = with pkgs; [
    opencode.packages.${pkgs.system}.default
  ];

  # Rest of your configuration...
}
```

#### Step 3: Apply Configuration

```bash
sudo nixos-rebuild switch
```

#### Test Installation

```bash
opencode --help
opencode status
```

#### Update OpenCode

Update the flake lockfile and apply:

```bash
sudo nix flake update
sudo nixos-rebuild switch
```

Or in one command:

```bash
sudo nixos-rebuild switch --update-input opencode
```

---

### Approach B: Separate System Flake (Idiomatic NixOS)

For more complex setups or when managing multiple machines, use a dedicated system flake.

#### Step 1: Create /etc/nixos/flake.nix

```nix
{
  description = "NixOS system configuration with OpenCode";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    opencode = {
      url = "github:TobsenD/opencode";
      # For local development:
      # url = "path:/path/to/local/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, opencode }:
    {
      nixosConfigurations = {
        # Replace 'hostname' with your actual hostname
        hostname = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit opencode;
          };
          modules = [
            ./hardware-configuration.nix
            ./configuration.nix
          ];
        };
      };
    };
}
```

#### Step 2: Update /etc/nixos/configuration.nix

```nix
{ config, pkgs, opencode, ... }:
{
  # Add OpenCode to system packages
  environment.systemPackages = [
    opencode.packages.${pkgs.system}.default
  ];

  # Rest of your configuration...
}
```

#### Step 3: Initialize Flake

If not already using flakes:

```bash
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
```

#### Step 4: Apply Configuration

```bash
sudo nixos-rebuild switch --flake /etc/nixos#hostname
```

Or if `/etc/nixos` is a Git repository:

```bash
cd /etc/nixos
sudo nixos-rebuild switch
```

#### Update

```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch
```

---

## First Time Usage

After installation with any method:

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

---

## Post-Installation Configuration

### Customize Configuration (Optional)

Edit config files in `~/.opencode-container/config/`:

- `git/config` - Git configuration for containers
- `opencode/opencode.jsonc` - OpenCode app configuration
- `opencode/tui.jsonc` - TUI theme settings
- `opencode/AGENTS.md` - Agent behavior guidelines

### Verify Zsh Completion

In a new zsh shell:

```bash
opencode <TAB>
```

You should see available commands.

---

## Multiple Machines with Flakes

For managing OpenCode across multiple NixOS machines using a shared flake:

```nix
{
  outputs = { self, nixpkgs, opencode }:
    {
      nixosConfigurations = {
        machine1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit opencode; };
          modules = [ ./machines/machine1.nix ];
        };

        machine2 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit opencode; };
          modules = [ ./machines/machine2.nix ];
        };
      };
    };
}
```

Apply to specific machine:

```bash
sudo nixos-rebuild switch --flake .#machine1
```

---

## Troubleshooting

### "opencode: command not found"

**For per-user installations:** Ensure your shell profile sources the Nix profile:

```bash
# ~/.bashrc or ~/.zshrc
if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
  source $HOME/.nix-profile/etc/profile.d/nix.sh
fi
```

**For system-wide installations:** Verify the package was added correctly:

```bash
nix profile show  # per-user
systemctl restart systemd-logind  # system-wide, then re-login
```

### Flake Lockfile Out of Date

Update and rebuild:

```bash
nix flake update
nixos-rebuild switch  # or home-manager switch
```

Or update just OpenCode:

```bash
nix flake update --input opencode
nixos-rebuild switch  # or home-manager switch
```

### Symlink Conflicts

If you already have `~/.local/bin/opencode` from a previous installation:

```bash
# Remove old symlink
rm ~/.local/bin/opencode ~/.config/zsh/completions.d/_opencode

# Re-apply configuration
nixos-rebuild switch  # or home-manager switch
```

### "Cannot create symlink: Permission denied"

For system-wide installation, ensure you're using `sudo`:

```bash
sudo nixos-rebuild switch
```

### Git or Podman Not Available in Container

If containers can't access git or podman:

1. Verify host has them installed:
   ```bash
   which git podman
   ```

2. For system-wide installation, ensure they're in system packages:
   ```nix
   environment.systemPackages = with pkgs; [
     git
     podman
     opencode.packages.${pkgs.system}.default
   ];
   ```

3. Apply and rebuild:
   ```bash
   sudo nixos-rebuild switch
   ```

### "attribute 'homeManagerModules' missing"

Ensure you're referencing the correct flake output:

```nix
# Correct
opencode.homeManagerModules.default

# Incorrect (won't work)
opencode.nixosModules.default
```

---

## Comparison: When to Use Each Method

### Use nix profile install if:
- You want a quick test installation
- You don't need system-wide availability
- You prefer imperative (manual) updates
- You want minimal configuration

### Use home-manager if:
- You already use home-manager for user configuration
- You want declarative, version-controlled setup
- You manage per-user customizations
- You want easy rollback with `home-manager generations`

### Use nixos-rebuild switch if:
- You want system-wide availability for all users
- You prefer declarative, reproducible configurations
- You use NixOS flakes for system management
- You want the system state in version control

---

## Additional Resources

- **This Project (Container Wrapper & Installation Toolkit):** https://github.com/TobsenD/opencode
- **Original OpenCode Project:** https://github.com/anomalyco/opencode
- **Main Installation Guide:** [README.md](README.md)
- **NixOS Manual:** https://nixos.org/manual/nixos/stable/
- **Flakes Documentation:** https://nixos.wiki/wiki/Flakes
- **Home-Manager Manual:** https://nix-community.github.io/home-manager/
- **Podman Docs:** https://docs.podman.io

## License

OpenCode is provided as-is. See LICENSE file in the repository for details.

This wrapper and installation toolkit respects the license of the original OpenCode project at https://github.com/anomalyco/opencode.
