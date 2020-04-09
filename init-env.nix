{envth}:
with envth.lib;
rec {
  init-env = self:
    super@{ shellHook ? "", lib ? null, ... }:
    {  shellHook = ''
         [[ $ENVTH_ENTRY == bin ]] && ENVTH_BUILDDIR=.
         source ${mkEnvLib envth-lib}
         ${self.importLibsHook}
         ${if isNull lib then "" else "source $lib"}
         ''
         + shellHook ;
       userShellHook = shellHook;

    };
}
