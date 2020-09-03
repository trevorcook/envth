let
  nixpkgs = import <nixpkgs> { overlays = [ env-th-overlay ]; };
  env-th-overlay = self: super: { env-th = import env-th-src self super; };
  env-th-src = builtins.fetchGit {
      url = https://github.com/trevorcook/env-th.git ;
      rev = "b4836bae89263d9cc70e883f21fffaed9e296272"; };
in
{env-th ? nixpkgs.env-th }: with env-th;
mkEnvironment rec {
  # REQUIRED ARGS ####################

  # Used to determine output name:
  #    $out/bin/enter-${name}
  name = "sample";
  # Must refer to itself.
  definition = ./sample.nix;

  # OPTIONAL ##########################

  # Commands run upon shell entry
  shellHook = ''
    cat <<EOF
    Hello from ${name} environment
    setting b_file to no/such/file

    EOF
    b_file="no/such/file"
    show_b_file

  '';


  # As usual, environment variables can be defined with attributes.
  VAR1 = "sample VAR1";
  VAR2 = https://nixos.org;
  VAR3 = [ "a" "b" ];
  VAR4 = { __toString = _ : "I hold some data which won't be seen in the env";
           dat = "somehting"; };

  # The following attributes demonstrate `env-th.mkSrc` a utility
  # used to tag resources which can be "localized", that is, copied
  # from /nix/store to a local directory. Localized resources will
  # have the same file structure as the original.
  # Resources are localized from within the running environment with
  # `env-localize`
  a_dir = mkSrc ./a_dir;
  b_file = mkSrc ./b_dir/b_file.txt;

  # The `lib` attribute should be a set of text valued attributes.
  # Each attribute name becomes a shell function of the same name.
  # The values become the contents of the function.
  # mkEnvironment also adds two functions, ${name}-lib and ${name}-vars
  # which list the defined functions and vars (respectively).
  lib = {
    function-1 = ''
      echo this is function one, with args "$@"
      '';
    show_b_file = ''
      cat <<EOF
      In function show_b_file
      \''${b_file} is ${b_file}
      \''${b_file.local} is ${b_file.local}
      However, b_file is currently $b_file
      EOF
      '';

  };

  # A list of environments to be merged with the current one.
  # Attributes and `lib` of imported are added to the environment.
  # The `imports` are added in order they are listed, so any later
  # imports will override earlier variables and functions of the
  # same name.
  # Optional: List of in-scope mkEnvironment-derivations or paths to derivations
  imports = [
    ./imported_env.nix  #path to env file will be loaded using callPackage
    ];
  # mkEnvironment imports an initial environment, env-0, which
  # contains useful utilities. Try
  # > env-0-lib
  # to list contained functions.

}
