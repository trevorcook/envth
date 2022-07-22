{ envth }: with envth;
mkEnvironment rec { 
  name = "a";
  definition = ./a.nix;
  shellHook = ''
    ${passthru.greeting name}
    '';
  passthru.greeting = name: ''echo Welcome to ${name}'';

  paths = [];
  envlib = {};
}
