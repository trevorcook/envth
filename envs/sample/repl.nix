let
  nixpkgs = import <nixpkgs> { overlays = [ env-th-overlay ]; };
  env-th-overlay = self: super: { env-th = import env-th-src self super; };
  env-th-src = builtins.fetchGit {
      url = https://github.com/trevorcook/env-th.git ;
      rev = "59c712450b5f54c6b8f3a3b61f9cbb1670817fe8"; };
in rec {
  inherit nixpkgs;
  inherit (nixpkgs) lib callPackage env-th;
  env-th-b = env-th.override { envs = {inherit env-b;}; };
  sample = callPackage ./sample.nix {};
  sample-file = callPackage ./sample-file.nix {};
  env-a = callPackage ./env-a.nix { env-th = env-th-b;};
  env-a-file = callPackage ./env-a-file.nix { env-th = env-th-b;};
  env-b = callPackage ./env-b.nix {};

}
