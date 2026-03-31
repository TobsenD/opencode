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
            mkdir -p $out/lib/opencode/{bin,completion,container,config/git,config/opencode}

            # Copy main script
            cp script/opencode.sh $out/lib/opencode/bin/opencode.sh
            chmod +x $out/lib/opencode/bin/opencode.sh

            # Copy zsh completion
            cp completion/_opencode.zsh $out/lib/opencode/completion/_opencode.zsh

            # Copy container definition
            cp container/Containerfile $out/lib/opencode/container/

            # Copy config templates
            cp config/git/config $out/lib/opencode/config/git/
            cp config/opencode/AGENTS.md $out/lib/opencode/config/opencode/
            cp config/opencode/opencode.jsonc $out/lib/opencode/config/opencode/
            cp config/opencode/tui.jsonc $out/lib/opencode/config/opencode/

            # Create wrapper script that initializes ~/.opencode-container and runs opencode
            mkdir -p $out/bin
            cat > $out/bin/opencode << 'WRAPPER'
            #!/${pkgs.bash}/bin/bash
            set -euo pipefail

            # First-time setup: copy files to ~/.opencode-container if not present
            if [[ ! -d "$HOME/.opencode-container" ]]; then
              mkdir -p "$HOME/.opencode-container/bin"
              mkdir -p "$HOME/.opencode-container/completion"
              mkdir -p "$HOME/.opencode-container/container"
              mkdir -p "$HOME/.opencode-container/config/git"
              mkdir -p "$HOME/.opencode-container/config/opencode"

              # Copy files from package to user's home
              cp ${placeholder "out"}/lib/opencode/bin/opencode.sh "$HOME/.opencode-container/bin/"
              cp ${placeholder "out"}/lib/opencode/completion/_opencode.zsh "$HOME/.opencode-container/completion/"
              cp ${placeholder "out"}/lib/opencode/container/Containerfile "$HOME/.opencode-container/container/"
              
              # Copy config files (only if they don't exist)
              [[ ! -f "$HOME/.opencode-container/config/git/config" ]] && \
                cp ${placeholder "out"}/lib/opencode/config/git/config "$HOME/.opencode-container/config/git/"
              [[ ! -f "$HOME/.opencode-container/config/opencode/AGENTS.md" ]] && \
                cp ${placeholder "out"}/lib/opencode/config/opencode/AGENTS.md "$HOME/.opencode-container/config/opencode/"
              [[ ! -f "$HOME/.opencode-container/config/opencode/opencode.jsonc" ]] && \
                cp ${placeholder "out"}/lib/opencode/config/opencode/opencode.jsonc "$HOME/.opencode-container/config/opencode/"
              [[ ! -f "$HOME/.opencode-container/config/opencode/tui.jsonc" ]] && \
                cp ${placeholder "out"}/lib/opencode/config/opencode/tui.jsonc "$HOME/.opencode-container/config/opencode/"
            fi

            # Execute the opencode script from ~/.opencode-container
            exec "$HOME/.opencode-container/bin/opencode.sh" "''${@}"
            WRAPPER

            chmod +x $out/bin/opencode
          '';

          meta = with pkgs.lib; {
            description = "OpenCode - Container-based development environment";
            homepage = "https://github.com/TobsenD/opencode";
            license = licenses.unfree;
            platforms = platforms.all;
            maintainers = [ ];
          };
        };
      }
    ) // {
      # Home-manager module for declarative installation
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

            # Create ~/.opencode-container on first login
            home.activation.setupOpencode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
              if [[ ! -d "$HOME/.opencode-container" ]]; then
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/bin"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/completion"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/container"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/config/git"
                $DRY_RUN_CMD mkdir -p "$HOME/.opencode-container/config/opencode"

                # Copy files from package
                $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/bin/opencode.sh "$HOME/.opencode-container/bin/"
                $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/completion/_opencode.zsh "$HOME/.opencode-container/completion/"
                $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/container/Containerfile "$HOME/.opencode-container/container/"

                # Copy config files (only if they don't exist - protect user customizations)
                [[ ! -f "$HOME/.opencode-container/config/git/config" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/git/config "$HOME/.opencode-container/config/git/"
                [[ ! -f "$HOME/.opencode-container/config/opencode/AGENTS.md" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/opencode/AGENTS.md "$HOME/.opencode-container/config/opencode/"
                [[ ! -f "$HOME/.opencode-container/config/opencode/opencode.jsonc" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/opencode/opencode.jsonc "$HOME/.opencode-container/config/opencode/"
                [[ ! -f "$HOME/.opencode-container/config/opencode/tui.jsonc" ]] && \
                  $DRY_RUN_CMD cp ${cfg.package}/lib/opencode/config/opencode/tui.jsonc "$HOME/.opencode-container/config/opencode/"
              fi
            '';

            # Create symlinks for direct access
            home.file.".local/bin/opencode".source = "${cfg.package}/bin/opencode";
            home.file.".config/zsh/completions.d/_opencode".source = "${cfg.package}/lib/opencode/completion/_opencode.zsh";
          };
        };
    };
}
