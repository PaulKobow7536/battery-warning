# battery-warning

A small battery low warning script that emits desktop notifications via
`notify-send` (works with [dunst](https://dunst-project.org/) or any other
notification daemon implementing the freedesktop notifications spec).

- **Warning** at less than 20% (configurable via `WARN_THRESHOLD`)
- **Critical** at less than 10% (configurable via `CRIT_THRESHOLD`)
- Skips notifications while charging
- Only renotifies when the level transitions (no spam)

## Files

| File | Purpose |
| ---- | ------- |
| `battery-warning.sh` | The check script |
| `battery-warning.service` | User systemd service that runs the script once |
| `battery-warning.timer` | User systemd timer that fires the service every minute |
| `flake.nix` | Nix flake exposing a package and a home-manager module |

## Manual install (non-NixOS)

```sh
install -Dm755 battery-warning.sh ~/.local/bin/battery-warning.sh
install -Dm644 battery-warning.service ~/.config/systemd/user/battery-warning.service
install -Dm644 battery-warning.timer   ~/.config/systemd/user/battery-warning.timer

systemctl --user daemon-reload
systemctl --user enable --now battery-warning.timer
```

Make sure `dunst` (or another notification daemon) and `libnotify`
(`notify-send`) are installed and available in your graphical session.

Test it manually:

```sh
WARN_THRESHOLD=100 ./battery-warning.sh
```

## NixOS / home-manager install

Add this flake as an input and import the home-manager module:

```nix
{
  inputs.battery-warning.url = "github:youruser/battery-warning";

  outputs = { self, nixpkgs, home-manager, battery-warning, ... }: {
    homeConfigurations."you@host" = home-manager.lib.homeManagerConfiguration {
      # ...
      modules = [
        battery-warning.homeManagerModules.battery-warning
        {
          services.battery-warning = {
            enable = true;
            warnThreshold = 20;
            critThreshold = 10;
            interval = "1min";
          };
          # Make sure a notification daemon is running, e.g.:
          services.dunst.enable = true;
        }
      ];
    };
  };
}
```

You can also just build the package:

```sh
nix build .#battery-warning
./result/bin/battery-warning
```

## Configuration

The script honors these environment variables:

- `WARN_THRESHOLD` (default `20`)
- `CRIT_THRESHOLD` (default `10`)
- `BATTERY_PATH` (default `/sys/class/power_supply/BAT0`, falls back to first `BAT*`)
