{env-th, name, python, callPackage}:
env-th.mkEnvironment rec {
  inherit name;
  definition = ./python-env.nix;
  passthru = {
    inherit python;
    addPackages = f: let
      next-python = python.override (old: {
        extraLibs = old.extraLibs ++ (f python.pkgs);});
      in callPackage definition {inherit name env-th callPackage;
                                 python = next-python;};
    };
  }
