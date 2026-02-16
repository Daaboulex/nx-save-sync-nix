{
  description = "NX-Save-Sync - Switch save sync tool for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          nx-save-sync = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.nx-save-sync;
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.nx-save-sync ];
          packages = with pkgs; [
            python3
            python3Packages.pip
          ];
        };
      }
    ) // {
      # NixOS module
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.nx-save-sync;
        in
        {
          options.programs.nx-save-sync = {
            enable = lib.mkEnableOption "NX-Save-Sync switch save synchronization tool";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.nx-save-sync;
              description = "The NX-Save-Sync package to use";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      # Overlay
      overlays.default = final: prev: {
        nx-save-sync = self.packages.${prev.stdenv.hostPlatform.system}.nx-save-sync;
      };
    };
}
