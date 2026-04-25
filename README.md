# nx-save-sync-nix

[![CI](https://github.com/Daaboulex/nx-save-sync-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/nx-save-sync-nix/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Daaboulex/nx-save-sync-nix)](./LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![Last commit](https://img.shields.io/github/last-commit/Daaboulex/nx-save-sync-nix)](https://github.com/Daaboulex/nx-save-sync-nix/commits)
[![Stars](https://img.shields.io/github/stars/Daaboulex/nx-save-sync-nix?style=flat)](https://github.com/Daaboulex/nx-save-sync-nix/stargazers)
[![Issues](https://img.shields.io/github/issues/Daaboulex/nx-save-sync-nix)](https://github.com/Daaboulex/nx-save-sync-nix/issues)

Nix flake for [NX-Save-Sync](https://github.com/Xc987/NX-Save-Sync) — Switch save sync tool.

## Upstream

This is a **Nix packaging wrapper** — not the original project. All credit for NX-Save-Sync goes to:

- **Author**: [Xc987](https://github.com/Xc987)
- **Repository**: [github.com/Xc987/NX-Save-Sync](https://github.com/Xc987/NX-Save-Sync)
- **License**: [GPL-3.0](https://github.com/Xc987/NX-Save-Sync/blob/main/LICENSE)

## What Is This?

A Nix flake that builds NX-Save-Sync from upstream releases with full CI infrastructure:

- **Daily automated updates** via GitHub Actions — new upstream releases land here within 24 h
- **Pre-build verification** — fail-closed pipeline (eval → build → desktop check) before any push to `main`
- **NixOS module** — exposes `programs.nx-save-sync.enable` for declarative install

NX-Save-Sync syncs save files between a Nintendo Switch and emulator (Ryujinx/Eden), or between multiple modded consoles.

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

## Development

```bash
git clone https://github.com/Daaboulex/nx-save-sync-nix
cd nx-save-sync-nix
nix develop                       # enter dev shell, installs pre-commit hooks
nix fmt                           # format flake
nix flake check --no-build        # eval check
nix build                         # build the package
./result/bin/nx-save-sync --help  # binary verify (mirrors CI desktop check)
```

CI runs the same chain daily via `.github/workflows/update.yml`; manual updates rarely needed.

## License

This packaging flake is [GPL-3.0](./LICENSE) licensed (matches upstream). Upstream NX-Save-Sync is [GPL-3.0](https://github.com/Xc987/NX-Save-Sync/blob/main/LICENSE).
