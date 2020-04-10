{env-th, env0}:
with env-th.lib;
rec {
  init-env = self:
    super@{ shellHook ? "", lib ? null, ... }:
    {  shellHook = ''
         [[ $ENVTH_ENTRY == bin ]] && ENVTH_BUILDDIR=.
         source ${mkEnvLib env0}
         ${if self ? importLibsHook then self.importLibsHook else ""}
         ${if isNull lib then "" else "source $lib"}
         ''
         + env0.shellHook
         + shellHook ;
       userShellHook = shellHook;

    };
}
