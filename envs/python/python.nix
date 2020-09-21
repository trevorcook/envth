self: super: with self.lib;
let
  pyVersions = [ "python"
                 "python2" "python27"
                 "python3" "python35" "python36" "python37" "python38" "python39"
               ];
  make-python-version = name:
    let pyenv = (getAttr name self).withPackages (_:[]);
    in { inherit name;
         value = make-python-env { inherit name pyenv;};
       };
  make-python-env = makeOverridable ({ name, pyenv}: with self.env-th;
    let
      pyenv-old = pyenv;
      thisEnv = mkEnvironment {
        inherit name;
        definition = ./python-env.nix;
        passthru = {
          env = pyenv-old;
          addPackages = f: let
            pyenv = pyenv-old.override (old: {
              extraLibs = old.extraLibs ++ (f pyenv-old.pkgs);});
            in make-python-env {inherit name pyenv;};
          };
        };
    in thisEnv);

in listToAttrs (map make-python-version pyVersions)
