{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    sops-nix-wrapper = {
      url = "github:vdbe/sops-nix-wrapper";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };

    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self, nixpkgs, sops-nix-wrapper,... }:
    let 
      inherit (nixpkgs) lib;

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          function (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      secretsDir = ./.;
      config = import sops-nix-wrapper.outPath {inherit lib secretsDir;};
      config' = import (sops-nix-wrapper.outPath + "/convertConfigPaths.nix") {inherit lib secretsDir config;};
    in
    {
      inherit config;

      nixosModules.default = sops-nix-wrapper.nixodModules.default;

      packages = forAllSystems (
        pkgs:
        let
          configJson = pkgs.writeText "configJson" (builtins.toJSON config');

          generate-sops-yaml = pkgs.writeShellScriptBin "generate-sops-yaml" ''
            exec ${sops-nix-wrapper.packages.${pkgs.system}.generate-sops-yaml-script}/bin/generate-sops-yaml ${configJson}
          '';

        in
        {
          inherit generate-sops-yaml configJson;
        }
      );

    };
}
