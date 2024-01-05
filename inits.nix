{lib, envth, pkgs}:
with lib; with envth.lib;
# Utilities for initializing the environment processing (save-attrs-by),
# and initializing the running shell (init-env/set-default-build-dir)
rec {

  derive-definition = {};
  # ???
  accum-attrs-by = fs: attr: foldl'
    (acc: f: recursiveUpdate acc (f acc)) attr fs;

  save-attrs-as = name: self: super@{passthru ? {}, ... }:
    /* { passthru = filterAttrs (n: v: n == "passthru" ) super; }; */
  let f = _: { "${name}" = super; };
    in { passthru = accum-attrs-by [f] passthru; };
      /* __toString = x:""; */

  add-passthru-pkgs = self: super: { 
    passthru = super.passthru // {inherit pkgs; };
    };

  set-default-build-dir = self: super@{definition, ...}:
    diffAttrs { ENVTH_BUILDDIR = dirOf (toString definition);} super;

  init-env = self:
    super@{ shellHook ? "", name, ... }:
    {  shellHook = 
           (attrByPath ["importLibsHook"] "" self)
         + (attrByPath ["importCmdsHook"] "" self)
         + envth.lib.env0.shellHook
         + shellHook ;
       userShellHook = shellHook;

    };

}
