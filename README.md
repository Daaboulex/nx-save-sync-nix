# nx-save-sync-nix

Nix flake for [NX-Save-Sync](https://github.com/Xc987/NX-Save-Sync) - Switch save sync tool.

NX-Save-Sync syncs save files between a Nintendo Switch and emulator (Ryujinx/Eden) or between multiple modded consoles.

**This package tracks upstream releases** with daily automated updates via GitHub Actions.

## Installation

### As a flake input

```nix
{
  inputs.nx-save-sync.url = "github:daaboulex/nx-save-sync-nix";

  outputs = { nixpkgs, nx-save-sync, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [ nx-save-sync.packages.${pkgs.system}.nx-save-sync ];
        })
      ];
    };
  };
}
```

### Using the NixOS module

```nix
{
  imports = [ nx-save-sync.nixosModules.default ];
  programs.nx-save-sync.enable = true;
}
```

### Direct run

```bash
nix run github:daaboulex/nx-save-sync-nix
```

## Usage

1. Run `nx-save-sync` from your application menu or terminal
2. Configure your Switch IP and save paths
3. Sync saves between Switch and emulator

## Requirements

- A modded Nintendo Switch with the NX-Save-Sync homebrew installed
- Network connection between PC and Switch

## License

GPL-3.0 (same as upstream)
