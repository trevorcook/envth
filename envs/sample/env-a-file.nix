{env-th}:
/* with env-th.addEnvs [./env-b.nix]; mkEnvironment */
with env-th.addEnvs []; mkEnvironment
{ name = "env-a";
  definition = ./env-a.nix;
  buildInputs = [ ];
  varA = "varA set in env-a";
  imports = [ ./env-b.nix ];
  /* addEnvs = [ ./env-b.nix ]; */
  varB-refA  = envs.env-b.varB;
  lib = {
    lib-a-f = '' echo "env-a lib" '';
  };
}
