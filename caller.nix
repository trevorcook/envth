{envth,writeText,path,lib}: with lib; rec {
  # add-caller adds a derivation that can be used to call an
  # environment with callPackage. This is used by env0.envlib.env-reload
  add-caller = self: super: {
    ENVTH_CALLER =
      let caller_ = attrByPath ["env-caller"] caller-file super;
      in if caller_ == "none" then null-caller-file else caller_;
    };

  null-caller-file = writeText "null-caller.nix" ''
    {definition}: definition {}'';

  caller-file = writeText "caller.nix" ''
    {definition}: let
      get-pkgs = config:
        let
          pkgs-sys = builtins.tryEval (import <nixpkgs> config);
          pkgs-on-build = import ${path} config;
        in if pkgs-sys.success then pkgs-sys.value else pkgs-on-build;
      overlays = [ (self: super: { envth = import ${envth.path} self super; })];
      pkgs = let pkgs = get-pkgs {}; in
        if pkgs ? envth then pkgs else get-pkgs { inherit overlays; };
    in pkgs.callPackage definition {}'';
}
