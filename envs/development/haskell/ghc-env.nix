{env-th, name, selectFrom, haskellPackages}: #, callPackage}:
env-th.mkEnvironment rec {
  inherit name;
  definition = ./ghc-env.nix;
  passthru = {
    inherit selectFrom haskellPackages;
    ghc = haskellPackages.ghc.withPackages selectFrom;
    ghc-dev = haskellPackages.ghc.withHoogle selectFrom;
    addPackages = f: let
      next-selectFrom = pkgs: (selectFrom pkgs) ++ (f pkgs);
      in import definition
             { inherit name env-th haskellPackages;
                selectFrom = next-selectFrom; };
    };
  }
