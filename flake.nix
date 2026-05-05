{
  description = "NX-Save-Sync - Switch save sync tool for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { localSystem.system = system; };
        in
        {
          nx-save-sync = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.nx-save-sync;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      checks = forAllSystems (system: {
        pre-commit-check = git-hooks.lib.${system}.run {
          src = self;
          hooks.nixfmt-rfc-style.enable = true;
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            inputsFrom = [ self.packages.${system}.nx-save-sync ];
            packages = with pkgs; [
              nil
              python3
              python3Packages.pip
            ];
          };
        }
      );

      # NixOS module
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.nx-save-sync;
        in
        {
          options.programs.nx-save-sync = {
            enable = lib.mkEnableOption "NX-Save-Sync switch save synchronization tool";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.nx-save-sync;
              description = "The NX-Save-Sync package to use";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      # Overlay
      overlays.default = final: prev: {
        nx-save-sync = self.packages.${prev.system}.nx-save-sync;
      };
    };
}
