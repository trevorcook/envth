{ envth, figlet, lolcat }: 
# Add listed envrionments to envth.envs, bring envth in scope.
# let thisenvth =  envth.addEnvs [ envs/a.nix envs/b.nix ];
# in
with envth.addEnvs [ envs/a.nix envs/b.nix ];
mkEnvironment rec
{ 
  name = "example"; # Used in package name, output executables.
  definition = ./env.nix; # Allows env to reload its (updated) self.

  paths = [figlet lolcat]; # Add some programs to the path.

  # Tag env folder as a resource that can be localized with `envth localize`.
  envs_dir = mkSrc ./envs;
  # Resources resolve to local paths in shell environment, this delivers the 
  # store location instead. 
  envs_dir_store = envs_dir.store;  

  # shellHook is run on entry (but not for imported environments).
  # The true shell hook has additional inits, this value will be stored as
  # userShellHook
  shellHook = ''
    ${envs.a.greeting name /*Uses the greeting function from env a */ }
    ${envs.a.userShellHook /*Also run the env a shell Hook */ }
    '';

  # Brings environment "a" into same scope as current environment. That is, 
  # whenever `envth.addEnvs [full]` is called, {full, a} will be included in 
  # envth.envs of the caller. 
  # Additionally, this will add environment `a` to the flake, enabling e.g.
  # nix develop .#a
  env-addEnvs = with envs; [ a ];

  # For switching between sets of environment variables with `envth varsets`
  env-varsets={ c = {x="x from varset c";};
                d = {x="x from varset d";}; };

  # merges the paths, envlib, and attributes into current environment.
  # imports = with envs; [ a b ];
  imports = with envs; [ a b ];
  
  # Passthru can be used as in regular derivations. Use `envth repl` to load 
  # current environment definition. Some extra passthru attributes, such as flake
  # pkgs, and envs-added, are added automatically by envth for convenience.
  passthru.internal-fcn = a: {inherit a;};

  # [metafun](github.com/trevorcook/nix-metafun) functions added to the environment.
  envlib = {
    full-greeting =  {
      opts.bye.desc = "Say bye instead";
      opts.bye.set = "saybye";
      hook = ''
        if [[ -n $saybye ]]; then
          echo "Good bye"
        else
          echo "Hello"
        fi
      '';
    };
  };
}
