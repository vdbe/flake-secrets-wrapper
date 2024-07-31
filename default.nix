specialArgs@{
  lib ? (import <nixpkgs> {}).lib,
  secretsDir ? ./template/simple,
  ...
}:
let
  evalResult = lib.evalModules {
    modules = [
      (import ./secretsModule.nix specialArgs)
      (_: { imports = [ secretsDir ]; })
    ];
  };

in
evalResult.config
