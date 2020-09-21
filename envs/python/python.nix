self: super: with self.lib;
let
  pyVersions = [ "python"
                 "python2" "python27"
                 "python3" "python35" "python36" "python37" "python38" "python39"
               ];
  make-python-version = name:
    let pyenv = getAttr name self;
    in { inherit name;
      value = make-python-env name (pyenv.withPackages (_:[]));
    };
  make-python-env = name: pyenv: with self.env-th;
    mkEnvironment rec {
      inherit name;
      definition = ./python-env.nix;
      buildInputs = [] ;
      passthru = rec {
        env = pyenv;
        addPackages = f: let
          new-pyenv = pyenv.override (old: {
            extraLibs = old.extraLibs ++ (f pyenv.pkgs);});
          in make-python-env name new-pyenv;
      };
    };

in listToAttrs (map make-python-version pyVersions)
