
{
  description = "The 'envth' overlay and project templates.";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    metafun.url = "path:/home/tcook/projects/nix-metafun";
  };
  outputs = { self,nixpkgs, metafun }@inputs: rec { 
    templates.default = templates.new;
    templates.new = {
      path = templates/new;
      description = "A minimal envth template.";
      welcomeText = ''# Initializing new envth template.
        Run `envth enter`.
        '';
    };

    packages = builtins.mapAttrs (system: pkgs_: 
      let pkgs = pkgs_.extend (_: _: inputs.metafun.packages."${system}");
          envthpkg = pkgs.callPackage ./envth.nix { flakePath = self ;};
      in {envth = envthpkg;} ) nixpkgs.legacyPackages;
   
    devShells = builtins.mapAttrs (system: pkgs: rec {
      envth = pkgs.mkShell {
        packages = [ packages."${system}".envth ];
        shellHook = "cd /home/tcook/projects/envth-test";
      };
    }) nixpkgs.legacyPackages;
  
  };


}
