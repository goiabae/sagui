{
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux; in

    let fetchFromGitHub = pkgs.fetchFromGitHub; in
    let fetchFromGitea = pkgs.fetchFromGitea; in
    let fetchurl = pkgs.fetchurl; in
    let buildLuarocksPackage = pkgs.luaPackages.buildLuarocksPackage; in

    let argparse = pkgs.luaPackages.argparse; in
    let inspect = pkgs.luaPackages.inspect; in
    let luafilesystem = pkgs.luaPackages.luafilesystem; in
    let lusc_luv = pkgs.luaPackages.lusc_luv; in
    let luv = pkgs.luaPackages.luv; in
    let tl = pkgs.luaPackages.tl; in
    let dkjson = pkgs.luaPackages.dkjson; in
    let cyan = pkgs.luaPackages.cyan; in
    let penlight = pkgs.luaPackages.penlight; in
    let busted = pkgs.luaPackages.busted; in
    let dkjson = pkgs.luaPackages.dkjson; in
    let dkjson = pkgs.luaPackages.dkjson; in

    # Copied from nixpkgs nixos-25.11 tag
    let teal-language-server = pkgs.callPackage (
      { argparse
      , buildLuarocksPackage
      , dkjson
      , fetchFromGitHub
      , fetchurl
      , inspect
      , luafilesystem
      , lusc_luv
      , luv
      , tl
      }:

      buildLuarocksPackage {
        pname = "teal-language-server";
        version = "0.0.5-1";
        knownRockspec =
          (fetchurl {
            url = "mirror://luarocks/teal-language-server-0.0.5-1.rockspec";
            sha256 = "11ps1hgkgli4sf9gcj7pin4kbc5w0yck0daig1ghqssn2q9m2x5l";
          }).outPath;
        src = fetchFromGitHub {
          owner = "teal-language";
          repo = "teal-language-server";
          # There is no 0.0.5 tag, but this was the commit that change to from 0.0.4 to 0.0.5
          rev = "6e50c7d907b150b1b2e03fb5d70f0f3c63dec5c3";
          hash = "sha256-lTCTePaAYW4pqbJznos3BM0I0/Vaw13TNCCatmQjIJo=";
        };

        propagatedBuildInputs = [
          argparse
          dkjson
          inspect
          luafilesystem
          lusc_luv
          luv
          tl
        ];

        meta = {
          homepage = "https://github.com/teal-language/teal-language-server";
          description = "A language server for the Teal language";
          license.fullName = "MIT";
        };
      }
    ) { inherit argparse buildLuarocksPackage dkjson fetchFromGitHub fetchurl inspect luafilesystem lusc_luv luv tl; }; in

    let busted-tl = pkgs.callPackage (
      { buildLuarocksPackage
      , cyan
      , penlight
      , busted
      , tl
      , fetchurl
      , fetchFromGitea
      }:

      buildLuarocksPackage {
        pname = "busted-tl";
        version = "1.0.0";
        knownRockspec =
          (fetchurl {
            url = "https://forgejo.aireone.xyz/Aire-One/busted-tl/raw/commit/3623ef01f264cd8bd452d8cd3387ba4436fead4d/busted-tl-dev-1.rockspec";
            sha256 = "sha256-e/+xg9zxREaDHN14pROQwuENnyPtjfMcKDjAhDDnnAM=";
          }).outPath;
        src = fetchFromGitea {
          domain = "forgejo.aireone.xyz";
          owner = "Aire-One";
          repo = "busted-tl";
          rev = "v1.0.0";
          hash = "sha256-lTCTePaAYW4pqbJznos3BM0I0/Vaw13TNCCatmQjIJo=";
        };

        propagatedBuildInputs = [
          cyan
          penlight
          busted
          tl
        ];

        meta = {
          homepage = "https://gitea.aireone.xyz/Aire-One/busted-tl";
          description = "Busted-tl is a new Loader for Busted that adds Teal support.";
          license.fullName = "MIT";
        };
      }
    ) { inherit buildLuarocksPackage cyan penlight busted tl fetchurl fetchFromGitea; }; in

    {
      packages.x86_64-linux = {
        inherit busted-tl;
      };
      devShells.x86_64-linux.default = import ./shell.nix { inherit pkgs teal-language-server; };
    };
}
