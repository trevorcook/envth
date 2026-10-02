{lib, envth, envthcmd}:#, pkgs}:
with lib; with envth;
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

  # add-passthru-pkgs = self: super: { 
  #   passthru = super.passthru // {inherit pkgs; };
  #   };

  set-default-build-dir = self: super@{definition, ...}:
    diffAttrs { ENVTH_BUILDDIR = dirOf (toString definition);} super;

  init-env = self:
    super@{ shellHook ? "", name, ... }:
    {  shellHook = 
        # (attrByPath ["importLibsHook"] "" self) +
        # (attrByPath ["importCmdsHook"] "" self) +
        ''
        name=''${name%-env} #mkEnvrionment adds "env" to the name

        # Makes envth command into a function, so that e.g. exec envth reload 
        # does not nest environments.
        envth(){ source ${envthcmd}/bin/envth "$@" ; }
        source ${envthcmd}/share/bash-completion/completions/envth
        envth misc set-PS1
        envth misc PATH-nub
    
        # ENVTH_TEMP="$(mktemp -d "''${TMPDIR:-/tmp}/ENVTH_$name.XXX" 2>/dev/null)"
        # trap '[[ -n $ENVTH_TEMP ]] && rm -r $ENVTH_TEMP' EXIT'' 
        + shellHook ;
       userShellHook = shellHook;
    };

}
