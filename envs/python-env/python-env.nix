{ env-th, python3 } : with env-th;
let make-python-env = pyenv: mkEnvironment rec
{ name = "python-env";
  definition = ./shell.nix;
  definition_ = mkSrc ./python-env.nix;
  shellHook = ''
    '';
  buildInputs = [] ;
  passthru = rec {
    env = pyenv;
    addPackages = f: let
      new-pyenv = pyenv.override (old: {
        extraLibs = old.extraLibs ++ (f pyenv.pkgs);});
      in make-python-env new-pyenv;
  };
};
in make-python-env (python3.withPackages (_:[]))
