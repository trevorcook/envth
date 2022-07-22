{ envth }: 
with envth.addEnvs [ ];
mkEnvironment rec
{ 
  name = "env"; #FIXME
  definition = ./env.nix; 
  shellHook = '' '';

  paths = []; 

  imports = with envs; [ ];
  env-addEnvs = with envs; [ ];

  env-varsets = { };
  envlib = { };
}
