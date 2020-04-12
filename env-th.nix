self: super:
with builtins; with self.lib;
let callPackage = self.callPackage;
in rec {

  env0 = callPackage ./env-0.nix {};

  init-attrs = callPackage ./init-attrs.nix {};
  init-env = callPackage ./init-env.nix { inherit env0; };

  imports = callPackage ./imports.nix {};
  builder = callPackage ./build.nix {};
  resources = callPackage ./resources.nix {};
  mkSrc = ((callPackage ./resources.nix) {}).mkSrc;

  lib = callPackage ./lib.nix {};
  mkEnvironment = (callPackage ./mkEnvironment.nix { }).mkEnvironment;

  envs =
    let
      envsdir = filterAttrs (n: v: n != "README.md") (readDir ./envs);
      mkEnv = n: _: callPackage (./envs + "/${n}") {};
    in
      mapAttrs mkEnv envsdir;
}
