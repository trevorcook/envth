{ envth, name, selectFrom, haskellPackages, cabal2nix
, withHoogle?true, lib }: with lib; with builtins;
let ghc = haskellPackages.ghc.withPackages selectFrom;
    ghc-dev = haskellPackages.ghc.withHoogle selectFrom;
    ghc-on-path = if withHoogle then ghc-dev else ghc;
    mk-select = pkg-nix:
      let deps = attrNames (functionArgs (import pkg-nix));
        pre-filter = filter (pk: pk != "stdenv");
        post-filter = filter (x: all (y: typeOf x != y) ["null" "lambda"]);
        pick-dep = pkgs: name: getAttr name pkgs;
      in pkgs: post-filter (map (pick-dep pkgs) (pre-filter deps));
in envth.mkEnvironment rec {
  inherit name;
  definition = ./ghc-env.nix;
  paths = [cabal2nix ghc-on-path];
  passthru = rec {
    inherit selectFrom haskellPackages ghc ghc-dev;
    #makes new ghc environment with some added packages;
    addPackages = f: let
      next-selectFrom = pkgs: (selectFrom pkgs) ++ (f pkgs);
      in import definition
             { inherit name envth haskellPackages withHoogle cabal2nix lib;
                selectFrom = next-selectFrom; };
    # make new ghc environment with packages added from cabal2nix definition;
    addDeps = pkg-nix: addPackages (mk-select pkg-nix);
    };
  }
