{
  description = "Envth environment flake, including a package, app, and devShell for the listed env and all its added envrionments.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.envth.url = "github:trevorcook/envth";

  outputs = { self, nixpkgs, flake-utils, envth }:
    let
      env-file = ./env.nix;
      mkEnvs = envth.lib.make-flake-output self env-file;
    in flake-utils.lib.eachDefaultSystem mkEnvs;
}

