{
  config,
  lib ? (import <nixpkgs> {}).lib,
  ...
}: let 
  inherit (builtins) toString isPath isString;
  inherit (lib.attrsets) mapAttrsRecursive;
  inherit (lib.strings) removeSuffix removePrefix;

  root = removeSuffix "flake.nix" (toString config.flakePath);
  config' = mapAttrsRecursive (_: v: if (isPath v || isString v) then removePrefix root (toString v) else v) config;
in config'
