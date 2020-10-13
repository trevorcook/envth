{ pkgs, ... }: {
  packages = {
    backend = ./backend;
    common = ./common;
    frontend = ./frontend;
    };
  shells = {
    ghc = ["backend" "common" "frontend"];
    ghcjs = ["common" "frontend"];
    };
  overrides = self: super: {
    reflex-dom-contrib = self.callCabal2nix "reflex-dom-contrib"
       ( pkgs.fetchFromGitHub
         { owner = "reflex-frp";
           repo = "reflex-dom-contrib";
             rev = "11db20865fd275362be9ea099ef88ded425789e7";
             sha256 = "1rmcqg97hr87blp1vl15rnvsxp836c2dh89lwpyb7lvh86d7jwaf";
          }) {};
    };
  }
