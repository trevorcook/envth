{ envth }: with envth;
mkEnvironment rec { 
  name = "b";
  definition = ./b.nix;
  shellHook = ''
    echo Welcome to ${name}
    '';
  paths = [];
  envlib = {};
}
