self: super: with self.lib;
let
  ghcVers = [ "ghc844" "863Binary" "ghc865" "ghc881"
              "ghc882" "ghc883" "ghc884" "ghcHEAD"
              "ghcjs" "ghcjs86"
            ];
  make-haskell-version = name:
    let haskellPackages = getAttr name self.haskell.packages;
        selectFrom = _: [];
    in { inherit name;
         value = self.callPackage ./ghc-env.nix {
           inherit name haskellPackages selectFrom;};
       };
in listToAttrs (map make-haskell-version ghcVers)
   // { "ghc" = self.callPackage ./ghc-env.nix {
           name = "ghc";
           selectFrom = _: [];
           inherit (self) haskellPackages;
           };
      }
