{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    systems.url = "github:nix-systems/default";

  };

  outputs =
    {
      nixpkgs,
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

      config = import ./default.nix {
        inherit lib;
        secretsDir = ./template/simple;
      };
      config' = import ./convertConfigPaths.nix {inherit config lib;};
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      templates = {
        simple = {
          description = ''
            Simple example.
          '';
          path = ./template/simple;
        };
      };

      nixosModules.default = import ./nixosModule.nix;

      devShells = forAllSystems (pkgs: {
        default = pkgs.callPackage ./shell.nix { };
      });

      inherit config config';

      packages = forAllSystems (
        pkgs:
        let
          configJson = pkgs.writeText "configJson" (builtins.toJSON config');
          generate-sops-yaml-script = pkgs.python3Packages.buildPythonApplication rec {
            pname = "generate-sops-yaml";
            version = "0.1.0";
            format = "other";

            dontUnpack = true;
            installPhase = ''
              install -Dm755 ${./scripts/generate-sops-yaml.py} $out/bin/${pname}
            '';
          };

          generate-sops-yaml = pkgs.writeShellScriptBin "generate-sops-yaml" ''
            exec ${generate-sops-yaml-script}/bin/generate-sops-yaml ${configJson}
          '';

        in
        {
          inherit generate-sops-yaml configJson generate-sops-yaml-script;
        }
      );
    };
}
