let nixpkgs = import <nixpkgs> {};
    envthdef = import ../../env-th.nix nixpkgs {}; in
{env-th ? envthdef }: with env-th;
mkEnvironment {
  # Used to determine output name:
  #    $out/bin/enter-${name}
  # REQUIRED
  name = "sample";

  # Must refer to itself.
  # REQUIRED
  definition = ./sample.nix;

  # As usual, environment variables can be defined with attributes.
  VAR1 = "sample VAR1";

  # The following attributes demonstrate `env-th.mkSrc` a utility
  # used to tag resources which can be "localized", that is, copied
  # from /nix/store to a local directory. Localized resources will
  # have the same file structure as the original.
  a_dir = mkSrc ./a_dir;
  b_file = mkSrc ./b_dir/b_file.txt;

  # The `lib` attribute should be a set of text valued attributes.
  # Each attribute name becomes a shell function of the same name.
  # The values become the contents of the function.
  # mkEnvironment also adds two functions, ${name}-lib and ${name}-vars
  # which list the defined functions and vars (respectively).
  # OPTIONAL
  lib = {
    function-1 = ''
      echo this is function one, with args "$@"
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
