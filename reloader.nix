{env-th,writeText,env0,path,lib}: with lib; rec {
  # add-reloader adds a derivation that can be (supposed to be able to be)
  # used to call an
  # environment with callPackage. This is used by env-0.lib.env-reload
  add-reloader = self: super: {
    ENVTH_CALLER =
        attrByPath ["env-reloader"] reloader-file super;
    };

  reloader-file = writeText "reloader.nix" ''
    {definition}: let
      get-pkgs = config:
        let
          pkgs-sys = builtins.tryEval (import <nixpkgs> config);
          pkgs-on-build = import ${path} config;
        in if pkgs-sys.success then pkgs-sys.value else pkgs-on-build;
      overlays = [ (self: super: { env-th = import ${env-th.src} self super; })];
      pkgs = let pkgs = get-pkgs {}; in
        if pkgs ? env-th then pkgs else get-pkgs { inherit overlays; };
    in pkgs.callPackage definition {}'';
}
