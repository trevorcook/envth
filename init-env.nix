{env-th}:
with env-th.lib;
rec {
  init-env = self:
    super@{ shellHook ? "", lib ? null, ... }:
    {  shellHook = ''
         [[ $ENVTH_ENTRY == bin ]] && ENVTH_BUILDDIR=.
         source ${mkEnvLib envth-lib}
         ${if self ? importLibsHook then self.importLibsHook else ""}
         ${if isNull lib then "" else "source $lib"}
         ''
         + shellHook ;
       userShellHook = shellHook;

    };
}
