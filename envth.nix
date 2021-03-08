self: super:
with builtins; with self.lib;
let
  callPackage = self.callPackage;
  metafun-src = builtins.fetchGit {
      url = https://github.com/trevorcook/nix-metafun.git ;
      rev = "09d554ac7a7d9574e3bdddc93e6c2e89993428a1"; };
  metafun_ = callPackage (metafun-src + /metafun.nix) {};

  envs-dir = import ./envs/default.nix self super;
  /* envs-dir =  let
        envsdir = filterAttrs (n: v: n != "README.md") (readDir ./envs);
        mkEnv = n: _: callPackage (./envs + "/${n}") {};
      in
        mapAttrs mkEnv envsdir; */

  envth0 = mkenvth {};
  mkenvth =  makeOverridable ({envs ? envs-dir, metafun?metafun_ }:
    # callPackage will use the original `envth`. To pick up the overridden
    # definition, an updated `envth` must be supplied--hence the following.
    let envth = envth0.override {inherit envs;}; in
    rec {
    # This is all the utilities going into making it work.
    lib = rec {
      # envth modules.
      env0 = callPackage ./env0.nix { inherit envth; };
      inits = callPackage ./inits.nix { inherit envth; };
      add-envs = callPackage ./add-envs.nix { inherit envth; };
      imports = callPackage ./imports.nix { inherit envth;};
      builder = callPackage ./build.nix { inherit envth; };
      resources = callPackage ./resources.nix {};
      envlib = callPackage ./envlib.nix { inherit metafun; };
      make-environment = callPackage ./make-environment.nix { inherit envth; };
      caller = callPackage ./caller.nix { };
      # Basic utilities used in some modules.
      callEnv = envth: x:
        if builtins.typeOf x == "path" then callPackage x
          { inherit envth; }
        else x;
      diffAttrs = a: b: removeAttrs a (attrNames b);
      };

    # These are the exported utilities.
    inherit envs;
    addEnvs = lib.add-envs.addEnvs;
    mkSrc = lib.resources.mkSrc;
    mkEnvironment = lib.make-environment.mkEnvironment;
    path = ./.;
  });
  in envth0
