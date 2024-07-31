
{
  lib ? (import <nixpkgs> { }).lib,
  secretsDir ? ./template/simple,
  ...
}:
{
  options.secrets = import ./secretsModule.nix  {inherit  lib secretsDir;};
  # config = {
  #   secrets = import secretsDir specialArgs;
  # };
}
