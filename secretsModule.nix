{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  secretsDir ? ./template/simple,
  ...
}:
let
  inherit (lib.strings) hasPrefix;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkOption;
  inherit (lib) types;

  sopsKeyOpt =
    { config, ... }:
    {
      options = {
        type = mkOption {
          type = types.enum [
            "age"
            "gpg"
          ];
        };
        key = mkOption { type = types.str; };
        id = mkOption { type = types.nullOr (types.strMatching "[a-z0-9_-]{3,}"); };
        desc = mkOption { type = types.nullOr types.str; };

      };
      config = {
        type = mkDefault (if (hasPrefix "age" config.key) then "age" else "gpg");
        id = mkDefault null;
        desc = mkDefault null;
      };
    };

  sopsKeyTypeWith =
    specialArgs:
    types.nonEmptyListOf (
      types.coercedTo types.str (k: { key = k; }) (
        types.submoduleWith {
          inherit specialArgs;
          shorthandOnlyDefinesConfig = true;
          modules = [ sopsKeyOpt ];
        }
      )
    );
  sopsKeyType = sopsKeyTypeWith { };

  sopsFileOpts =
    {
      defaultKeys ? [ ],
      ...
    }:
    {
      options = {
        file = mkOption { type = types.path; };
        keys = mkOption { type = sopsKeyType; };
      };
      config = {
        keys = mkDefault defaultKeys;
      };
    };

  sopsFileTypeWithDefaultKeys =
    defaultKeys:
    types.coercedTo types.path (p: { file = p; }) (
      types.submoduleWith {
        specialArgs = {
          inherit defaultKeys;
        };
        modules = [ sopsFileOpts ];
      }
    );
  sopsFileType = sopsFileTypeWithDefaultKeys [ ];

  hostSecretOpts =
    { name, config, ... }:
    {
      options = {
        keys = mkOption { type = sopsKeyType; };
        host = mkOption { type = types.str; };
        dir = mkOption { type = types.path; };
        email = mkOption { type = types.str; };
        secretFiles = mkOption { type = types.attrsOf (sopsFileTypeWithDefaultKeys config.keys); };
      };
      config = {
        host = mkDefault name;
        email = mkDefault "${name}@localhost";
        keys = mkDefault [ ];
        dir = mkDefault (secretsDir + "/system/${config.host}");
        secretFiles = {
          # common = mkDefault ./common/default.sops.yaml;
          # default = mkDefault ./system/${config.host}/default.sops.yaml;
        };
      };
    };

  systemModule = {
    options = {
      flakePath = mkOption {
        type = types.path;
        description = "Used as prefix to remove when transforming to json";
        default = secretsDir + "/flake.nix";
      };
      masterKeys = mkOption {
        type = sopsKeyType;
        default = [ ];
      };
      hosts = mkOption {
        type = types.attrsOf (types.submodule hostSecretOpts);
        default = { };
      };
      keys = mkOption {
        type = types.attrsOf sopsKeyType;
        description = "Extra key groups to be used elsewhere";
        default = { };
      };
      secretFiles = mkOption {
        type = types.attrsOf sopsFileType;
        default = { };
      };
    };
    config = { };
  };
in
systemModule
