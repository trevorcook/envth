{
  description = "Envth environment flake, including a package, app, and devShell for the listed env and all its added envrionments.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.envth.url = "github:trevorcook/envth";

  outputs = { self, nixpkgs, flake-utils, envth }:
    let
      env-file = ./env.nix;
      mkEnvs = system:
        let
          envth-overlay = envth.overlays.envth;
          pkgs = nixpkgs.legacyPackages.${system}.extend envth-overlay;
          this-env = pkgs.callPackage env-file { };
          envs = this-env.envs-added // {
            "${this-env.name}" = this-env;
            default = this-env; };
          mkApp = n: v: { type = "app"; 
                          program = "${v}/bin/enter-env-${v.name}";};
        in
          { devShells = envs;
            packages = envs;
            apps = builtins.mapAttrs mkApp envs;
          };
    in flake-utils.lib.eachDefaultSystem mkEnvs;
}
