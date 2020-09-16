{env-th, gnused}: with env-th; mkEnvironment
{ name = "env-c";
  definition = ./env-c.nix;
  buildInputs= [ gnused ];
  varC = "varC set in env-c";
  imports = [ ./env-d.nix ];
  addEnvs = [ ./env-d.nix ];
}
