{
  pkgs ? import <nixpkgs> { },
  ...
}:
pkgs.mkShellNoCC {
  packages = with pkgs; [
    # sops
    sops
    age
    ssh-to-age

    # python
    (python3.withPackages (_: [ ]))
    ruff
    pyright

    # nix
    nixd
    deadnix
    nixfmt-rfc-style
    statix

    # yaml
    yaml-language-server

    # json
    vscode-langservers-extracted
  ];
}
