# The envth flake delivers an overlay, as opposed to an
# individual package due to the need for envth environments
# to supply their own package set.
{
  description = "The 'envth' overlay and project templates.";
  outputs = { self }:
    { overlays.envth = self: super: { envth = import ./envth.nix self super; };
      templates.full = {
        path = ./templates/full;
        description = "An environment with sepecial attributes defined.";
        welcomeText = ''
          # Full Envth Template
          This flake initializes a project with all available special attributes set to the appropriate null type ([],{}).

          Note: Changing environment file name must be reflected in 'definition' attribute and within flake.nix
          '';
      };
      templates.minimal = {
        path = ./templates/minimal;
        description = "A minimal envth environment.";
        welcomeText = ''
          # Minimal Envth Template
          This flake initializes a minimal envth project with only the required attributes defined.

          Note: Changing environment file name must be reflected in 'definition' attribute and within flake.nix
          '';
      };
      templates.example = {
        path = ./templates/example;
        description = "An example envth environment.";
        welcomeText = ''
          # Example Envth Template
          This flake initializes an example envth project.
          '';
      };
      templates.default = self.templates.minimal;
    };
}
