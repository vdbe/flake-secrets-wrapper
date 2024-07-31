specialArgs@{ lib, ... }:
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

  masterKeys = [
    {

      key = "age1t0gga8pltprn6ggy6lfq73x5lt5yh2ctyarh000ejx4ahnlnh4kqr3ull7";
      id = "master_key";
    }
  ];

}
