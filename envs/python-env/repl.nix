with builtins;
let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  definition = ./shell.nix;
in with pkgs; with lib; rec {
  inherit pkgs;
  python-env = callPackage ./python-env.nix {};
  shell = combine-py;
  py-env-1 = callPackage ./py-env-1.nix;
  py-env-2 = callPackage ./py-env-2.nix;
  combine-py = callPackage ./combine-py.nix {};
}
