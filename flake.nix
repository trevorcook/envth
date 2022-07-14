# The envth flake delivers an overlay, as opposed to an
# individual package due to the need for envth environments
# to supply their own package set.
{
  description = "Delivers the 'envth' overlay.";
  outputs = { self, nixpkgs, flake-utils }:
    { overlays.envth = self: super: {
        envth = import ./envth.nix self super;
      };
    };
}
