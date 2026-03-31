{
  description = "OpenCode - Container-based development environment with installer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # Development environment for working on OpenCode itself
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            git
            shellcheck
            podman
            coreutils
          ];
          
          shellHook = ''
            echo "OpenCode Development Environment"
            echo "Available commands:"
            echo "  ./install.sh        - Run the installer"
            echo "  ./script/opencode.sh - Test the opencode script"
            echo "  shellcheck install.sh - Check shell script syntax"
          '';
        };

        # User-installable OpenCode package
        packages.default = pkgs.stdenv.mkDerivation {
          name = "opencode";
          version = "1.0.0";
          
          src = self;

          # Runtime dependencies
          buildInputs = with pkgs; [
            bash
            podman
          ];

          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/lib/opencode
            mkdir -p $out/share/zsh/site-functions

            # Copy main script
            cp script/opencode.sh $out/bin/opencode
            chmod +x $out/bin/opencode

            # Copy zsh completion
            cp completion/_opencode.zsh $out/share/zsh/site-functions/_opencode

            # Copy container definition
            cp container/Containerfile $out/lib/opencode/

            # Copy config templates
            mkdir -p $out/lib/opencode/config/git
            mkdir -p $out/lib/opencode/config/opencode
            cp config/git/config $out/lib/opencode/config/git/
            cp config/opencode/AGENTS.md $out/lib/opencode/config/opencode/
            cp config/opencode/opencode.jsonc $out/lib/opencode/config/opencode/
            cp config/opencode/tui.jsonc $out/lib/opencode/config/opencode/

            # Copy installer
            cp install.sh $out/lib/opencode/

            # Create wrapper script that sets up the environment
            cat > $out/bin/opencode-init << 'WRAPPER'
            #!/${pkgs.bash}/bin/bash
            set -euo pipefail

            # First-time setup: copy files to ~/.opencode-container if not present
            if [[ ! -d "$HOME/.opencode-container" ]]; then
              mkdir -p "$HOME/.opencode-container"
              cp -r ${pkgs.lib.getLib}/../lib/opencode/* "$HOME/.opencode-container/"
            fi

            # Execute the opencode script
            exec "$HOME/.opencode-container/opencode.sh" "$@"
            WRAPPER

            chmod +x $out/bin/opencode-init
          '';

          meta = with pkgs.lib; {
            description = "OpenCode - Container-based development environment";
            homepage = "https://github.com/anomalyco/opencode";
            license = licenses.unfree; # Adjust based on your license
            platforms = platforms.all;
            maintainers = [ ];
          };
        };

        # Alternative package that uses the installer
        packages.with-installer = pkgs.stdenv.mkDerivation {
          name = "opencode-installer";
          version = "1.0.0";
          
          src = self;

          buildInputs = with pkgs; [
            bash
            coreutils
          ];

          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/share/opencode

            # Copy all source files
            cp -r . $out/share/opencode/

            # Create wrapper that runs the installer
            cat > $out/bin/opencode-install << 'WRAPPER'
            #!/${pkgs.bash}/bin/bash
            set -euo pipefail
            cd ${pkgs.lib.getLib}/../share/opencode/
            exec ./install.sh "$@"
            WRAPPER

            chmod +x $out/bin/opencode-install
          '';
        };
      }
    ) // {
      # Home-manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.opencode;
          opencodePkg = self.packages.${pkgs.system}.default;
        in
        {
          options.programs.opencode = {
            enable = mkEnableOption "OpenCode container development environment";

            package = mkOption {
              type = types.package;
              default = opencodePkg;
              description = "The OpenCode package to use";
            };
          };

          config = mkIf cfg.enable {
            # Add opencode to PATH
            home.packages = [ cfg.package ];

            # Install zsh completion if using zsh
            programs.zsh.completionInit = ''
              # OpenCode completion
              fpath+=(${cfg.package}/share/zsh/site-functions)
            '';

            # Create ~/.opencode-container on first login
            home.activation.setupOpencode = hm.dag.entryAfter [ "linkGeneration" ] ''
              if [[ ! -d "$HOME/.opencode-container" ]]; then
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/config/git"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/config/opencode"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/bin"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/completion"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/container"

                # Copy config templates
                [[ ! -f "$HOME/.opencode-container/config/git/config" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/git/config "$HOME/.opencode-container/config/git/"
                [[ ! -f "$HOME/.opencode-container/config/opencode/AGENTS.md" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/opencode/AGENTS.md "$HOME/.opencode-container/config/opencode/"
                [[ ! -f "$HOME/.opencode-container/config/opencode/opencode.jsonc" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/opencode/opencode.jsonc "$HOME/.opencode-container/config/opencode/"
                [[ ! -f "$HOME/.opencode-container/config/opencode/tui.jsonc" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/opencode/tui.jsonc "$HOME/.opencode-container/config/opencode/"

                $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/container/Containerfile "$HOME/.opencode-container/container/"
              fi
            '';

            # Create ~/.local/bin/opencode symlink
            home.file.".local/bin/opencode".source = "${cfg.package}/bin/opencode";

            # Create zsh completion symlink
            home.file.".config/zsh/completions.d/_opencode".source = "${cfg.package}/share/zsh/site-functions/_opencode";
          };
        };
    };
}
