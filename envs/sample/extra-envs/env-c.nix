{envth, lolcat}: with envth; mkEnvironment
{ name = "env-c";
  definition = ./env-c.nix;
  paths= [ lolcat ];
  varC = "varC set in env-c";
  imports = [ ./env-d.nix ];
  env-addEnvs = [ ./env-d.nix ];
}
