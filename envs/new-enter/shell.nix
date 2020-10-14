{definition ? ./new-enter.nix }:
with import <nixpkgs> {};
  callPackage definition {}
