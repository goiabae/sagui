{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.lua54Packages.tl
    pkgs.lua54Packages.lua
    pkgs.lua54Packages.teal-language-server
    pkgs.stylua
  ];
}
