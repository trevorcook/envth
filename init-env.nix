{env-th, env0}:
rec {
  init-env = self:
    super@{ shellHook ? "", name, ... }:
    {  shellHook = ''
         ${if self ? importLibsHook then self.importLibsHook else ""}
         ''
         + env0.shellHook
         + shellHook ;
       userShellHook = shellHook;

    };
}
