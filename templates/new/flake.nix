{
  description = "Envth environment flake";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    envth.url = "path:/home/tcook/projects/envth";
    envth.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self,nixpkgs,envth}@inputs: rec { 
      packages = builtins.mapAttrs (system: pkgs_:
        let 
          pkgs = pkgs_.extend (_: _: envth.packages."${system}");
          this-env = pkgs.callPackage ./envth.nix {};
        in 
      {
        "${this-env.name}" = this-env;
        default = this-env;
      }) nixpkgs.legacyPackages;
      devShells = packages;
    };
    
}

