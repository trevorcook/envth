{env-th}:
with env-th.addEnvs [./env-b.nix]; mkEnvironment
{ name = "env-a";
  definition = ./env-a.nix;
  buildInputs = [ ];
  varA = "varA set in env-a";
  imports = [ envs.env-b ];
  addEnvs = [ envs.env-b ];
  varB-refA  = envs.env-b.varB;
  lib = {
    lib-a-f = '' echo "env-a lib" '';
  };
}
