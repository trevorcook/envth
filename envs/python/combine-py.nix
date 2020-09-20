{env-th}: with env-th.addEnvs [./py-env-1.nix ./py-env-2.nix];
mkEnvironment {
  name = "combine-py";
  definition = ./shell.nix;
  python_env = envs.python-env.env;
  shellHook = ''show-pkgs'';
  lib = { show-pkgs = ''echo "''${python_env}.../"
                        ls ''${python_env}/lib/python3.8/site-packages'';};
}
