{ envth }: with envth;
mkEnvironment { 
  name = "env"; #FIXME
  definition = ./env.nix;
  paths = [];
  envlib = {};
}
