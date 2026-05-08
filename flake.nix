{
  description = "Battery low warning script with dunst notifications and a user systemd service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # System-independent: home-manager module for user service installation.
      homeManagerModules.battery-warning = { config, lib, pkgs, ... }:
        let
          cfg = config.services.battery-warning;
          script = self.packages.${pkgs.system}.battery-warning;
        in {
          options.services.battery-warning = {
            enable = lib.mkEnableOption "battery low warning user service";

            warnThreshold = lib.mkOption {
              type = lib.types.int;
              default = 20;
              description = "Battery percentage at which a warning is shown.";
            };

            critThreshold = lib.mkOption {
              type = lib.types.int;
              default = 10;
              description = "Battery percentage at which a critical alert is shown.";
            };

            interval = lib.mkOption {
              type = lib.types.str;
              default = "1min";
              description = "How often to poll the battery state.";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.user.services.battery-warning = {
              Unit = {
                Description = "Battery low warning notification";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
              };
              Service = {
                Type = "oneshot";
                Environment = [
                  "WARN_THRESHOLD=${toString cfg.warnThreshold}"
                  "CRIT_THRESHOLD=${toString cfg.critThreshold}"
                  "PATH=${lib.makeBinPath [ pkgs.libnotify pkgs.coreutils ]}"
                ];
                ExecStart = "${script}/bin/battery-warning";
              };
              Install.WantedBy = [ "default.target" ];
            };

            systemd.user.timers.battery-warning = {
              Unit.Description = "Run battery low warning check periodically";
              Timer = {
                OnBootSec = cfg.interval;
                OnUnitActiveSec = cfg.interval;
                AccuracySec = "15s";
                Unit = "battery-warning.service";
              };
              Install.WantedBy = [ "timers.target" ];
            };
          };
        };
    in
    {
      inherit homeManagerModules;
      # Alias for the singular form some users expect.
      homeManagerModule = homeManagerModules.battery-warning;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        battery-warning = pkgs.stdenvNoCC.mkDerivation {
          pname = "battery-warning";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -Dm755 battery-warning.sh $out/bin/battery-warning
            wrapProgram $out/bin/battery-warning \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.libnotify pkgs.coreutils ]}
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "Battery low warning script using libnotify (dunst-compatible)";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "battery-warning";
          };
        };
      in {
        packages = {
          inherit battery-warning;
          default = battery-warning;
        };

        apps.default = {
          type = "app";
          program = "${battery-warning}/bin/battery-warning";
        };

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.shellcheck pkgs.libnotify ];
        };
      });
}
