{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-secrets-wrapper = {
      url = "github:vdbe/flake-secrets-wrapper";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };

    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-secrets-wrapper,
      ...
    }:
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
      config = import flake-secrets-wrapper.outPath { inherit lib secretsDir; };
      config' = import (flake-secrets-wrapper.outPath + "/convertConfigPaths.nix") {
        inherit lib secretsDir config;
      };
    in
    {
      inherit config;

      nixosModules.default = flake-secrets-wrapper.nixodModules.default;

      packages = forAllSystems (
        pkgs:
        let
          configJson = pkgs.writeText "configJson" (builtins.toJSON config');

          generate-sops-yaml = pkgs.writeShellScriptBin "generate-sops-yaml" ''
            exec ${
              flake-secrets-wrapper.packages.${pkgs.system}.generate-sops-yaml-script
            }/bin/generate-sops-yaml ${configJson}
          '';

        in
        {
          inherit generate-sops-yaml configJson;
        }
      );

    };
}
