{ pkgs ? import <nixpkgs> {}, teal-language-server }:

pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.luaPackages.tl
    teal-language-server
    pkgs.luaPackages.lua
    pkgs.stylua
  ];
}
