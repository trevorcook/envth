{env-th ? (import <nixpkgs> {}).env-th}: with env-th;
mkEnvironment {
  name = "imported_env";
  definition = ./imported_env.nix;

  VAR1 = "imported_env_VAR1";
  VAR2 = "imported_env_VAR2";

  lib = {
    function-imported-env = ''
      echo $VAR1 $VAR2
      '';
  };


}
