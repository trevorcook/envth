{envth, name, python, callPackage}:
envth.mkEnvironment rec {
  inherit name;
  definition = ./python-env.nix;
  passthru = {
    inherit python;
    addPackages = f: let
      next-python = python.override (old: {
        extraLibs = old.extraLibs ++ (f python.pkgs);});
      in callPackage definition {inherit name envth callPackage;
                                 python = next-python;};
    };
  }
