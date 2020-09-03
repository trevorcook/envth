self: super:
with builtins; with super.lib;
/* let
  callPackage = super.callPackage;
  env0 = callPackage ./env-0.nix { };
  env-th = {
    inherit env0;

    init-attrs = callPackage ./init-attrs.nix {};
    init-env = callPackage ./init-env.nix { inherit env0 env-th; };

    imports = callPackage ./imports.nix {inherit env-th;};
    builder = callPackage ./build.nix {inherit env-th;};
    resources = callPackage ./resources.nix {};
    mkSrc = ((callPackage ./resources.nix) {inherit env-th;}).mkSrc;

    lib = callPackage ./lib.nix {};
    mkEnvironment = (callPackage ./mkEnvironment.nix { inherit env-th;}).mkEnvironment;

    envs =
      let
        envsdir = filterAttrs (n: v: n != "README.md") (readDir ./envs);
        mkEnv = n: _: callPackage (./envs + "/${n}") {inherit env-th;};
      in
        mapAttrs mkEnv envsdir;
    };
in env-th */

let
  callPackage = self.callPackage;
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
