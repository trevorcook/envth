let addNumpy = ps: [ps.numpy]; in
  {env-th}: with env-th; mkEnvironment {
  name = "py-env-2";
  /* buildInputs = [ (python-env.addPackages (ps: [ps.numpy])) ]; */
  definition = ./py-env-2.nix;
  addEnvs = [ (env-th.envs.python-env.addPackages addNumpy) ];
}
