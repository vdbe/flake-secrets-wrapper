
secretsDir:
{
  lib ? (import <nixpkgs> { }).lib,
  ...
}:
{
  options.secrets = (import ./secretsModule.nix  {inherit  lib
    secretsDir;}).options;
  # config = {
  #   secrets = import secretsDir specialArgs;
  # };
}
