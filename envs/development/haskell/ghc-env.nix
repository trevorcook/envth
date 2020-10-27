{ envth, name, selectFrom, haskellPackages, cabal2nix
, package-cabal ? null# Enter the .cabal package
, withHoogle?true
}:
let ghc = haskellPackages.ghc.withPackages selectFrom;
    ghc-dev = haskellPackages.ghc.withHoogle selectFrom;
    ghc-on-path = if withHoogle then ghc-dev else ghc;
    /* cabal-dir =  */
in envth.mkEnvironment rec {
  inherit name;
  definition = ./ghc-env.nix;
  paths = [cabal2nix ghc-on-path];
  passthru = {
    inherit selectFrom haskellPackages;
    inherit ghc ghc-dev;
    addPackages = f: let
      next-selectFrom = pkgs: (selectFrom pkgs) ++ (f pkgs);
      in import definition
             { inherit name envth haskellPackages;
                selectFrom = next-selectFrom; };
    };
  envlib = {
    haskell-reload-env-with-updated-cabal = ''
       cabal2nix . '';
    };
  }
