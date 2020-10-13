self: super:
with builtins; with self.lib;
let
  haskell = import ./haskell self super;
  python = import ./python self super;
  reflex-platform = self.callPackage reflex-platform/reflex-platform-git.nix {};
  reflex-platform-env = self.callPackage ./reflex-platform
    { inherit reflex-platform; };
in {
  inherit haskell;
  ghc = haskell.ghc;
  reflex-platform = reflex-platform-env;
} // python
