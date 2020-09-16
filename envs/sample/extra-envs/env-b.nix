{env-th}: with env-th; mkEnvironment
{ name = "env-b";
  definition = ./env-b.nix;
  varB = "varB set in env-b";
  lib = {
    lib-b-f = '' echo "env lib-b" '';
  };
}
