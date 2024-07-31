specialArgs@{ config, lib, ... }:
let

  secretsHosts = {
    system01 = ./system/system01;
    system02 = ./system/system02;
  };

  commonSecrets = {
    common = common/default.sops.yaml;
  };

  hosts = builtins.mapAttrs (
    _: v:
    lib.mkMerge [
      {
        secretFiles = commonSecrets // {
          default = v + "/default.sops.yaml";
        };

      }
      (import v specialArgs)
    ]
  ) secretsHosts;
in
{
  inherit hosts;

  keys = {
    stage0 = [
      {
        id = "stage0";
        key = "age1cfwll67ak9fq4wd8m3w8l07wjhau9uckx5qdwm7mctm6lgqtmv7qmwgrvl";
        desc = "key used for bootstraping";
      }
    ];
  };

  secretFiles = {
    stage0 = {
      file = ./stage0/default.sops.yaml;
      keys = config.masterKeys;
    };
    apiKeys = {
      file = ./stage0/api_keys.sops.yaml;
      keys = config.masterKeys;
    };
  };

  masterKeys = [
    {

      key = "age1t0gga8pltprn6ggy6lfq73x5lt5yh2ctyarh000ejx4ahnlnh4kqr3ull7";
      id = "master_key";
    }
  ];

}
