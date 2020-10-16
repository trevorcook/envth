{env-th, lolcat}: with env-th; mkEnvironment
{ name = "env-c";
  definition = ./env-c.nix;
  paths= [ lolcat ];
  varC = "varC set in env-c";
  imports = [ ./env-d.nix ];
  addEnvs = [ ./env-d.nix ];
}
