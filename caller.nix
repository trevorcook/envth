{envth,writeText,path,lib,callPackage}: with lib; with envth.lib.envlib; rec {
  # add-caller adds a derivation that can be used to call an
  # environment with callPackage. This is used by env0.envlib.env-reload
  add-caller = self: super: {
    env-caller = null;
    /* ENVTH_CALLER =
      let caller_ = attrByPath ["env-caller"] null super;
      in if caller_ == "none" then null-caller-file
         else if caller_ == null then caller-file
         else mkCallSet caller_; */
    } // ( let caller_ = attrByPath ["env-caller"] null super;
           in if caller_ == "none" then
               { ENVTH_CALLSET = "{}";
                 ENVTH_CALLER = none-caller; }
            else if caller_ == null then
               { ENVTH_CALLSET = "{}";
                 ENVTH_CALLER = default-caller; }
            else
               { ENVTH_CALLSET = mkCallSet caller_;
                 ENVTH_CALLER = call-caller-file; } );
  mkCaller = attrs:
    { type = "env-caller";
      callSet = attrs;
      __toString = x: ""; #show-attrs-as-nix-set x.callSet;
    };
  mkCallSet = attrs: if isCaller attrs then attrs else
    { type = "env-caller";
      callSet = if isAttrs attrs then attrs else { definition = attrs; };
      __toString = x: show-attrs-as-nix-set x.callSet;
    };
  isCaller = x: (x ? type) && (x.type == "env-caller");

#seq empty-def

  none-caller = writeText "null-caller.nix" ''
    callSet: {definition}: definition {}'';
  call-caller-file = writeText "call-caller.nix" ''
    callSet@{definition,...}: defSet: with builtins;
      let
        caller = import definition;
        attrs' = intersectAttrs (functionArgs caller) (callSet // defSet);
      in caller attrs' '';

  default-caller = writeText "default-caller.nix" ''
    callSet: {definition}: let
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
  /* none-caller-file = writeText "null-caller.nix" ''
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
    in pkgs.callPackage definition {}''; */
  /* wrap-caller = caller: callPackage caller { definition = empty-def; };
  empty-def = writeText "empty-definition.nix" ''
    {envth,...}: with envth; with envth.lib;
      let this = make-environment.mkEnvironmentWith [builder.make-builder]
      { name = "empty-env";
        passthru = {inherit this;}; };
      in this''; */
