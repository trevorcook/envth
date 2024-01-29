{envth, lib}: with lib; with builtins;
rec {

  # Expand envth to include the list of environments. This uses a fixed
  # point to allow mutually dependent environments to be added.
  fix-envth-with = env-list:
    let
      envs0 = envth.envs;
      envs-added = fix (extends extend-envs (_: {}));
      extend-envs = self: super:
        let
          envs = foldr add-env super env-list;
          add-env = f: envs:
            let env = (envth.override { envs = envs0 // self; }).lib.callEnv f;
            in envs // env.envs-added // (setAttrByPath [env.name] env);
        in envs;

    in { envth = envth.override { envs = envs0 // envs-added; };
         inherit envs-added; };

  # Exported utility for use with `envth.addEnvs`
  addEnvs = addEnvs-nonfix;
  # This was the original addEnvs utility. However, interactions with
  # add-envs caused the possiblilty of circular import cycles.
  addEnvs-fix = env-list: (fix-envth-with env-list).envth;
  # This will add environments to `envth`. Environments are added in order.
  # Later environments may depend on earlier envioronments.
  addEnvs-nonfix =
    let
      make-new = envth: env_:
        let env = envth.lib.callEnv env_;
            added = attrByPath ["envs-added"] {} env;
            envs = envth.envs // added // (setAttrByPath [env.name] env);
        in envth.override { inherit envs; };
        # in envth // {inherit envs;};
    in foldl' make-new envth ;

  # Overlay that adds `addEnvs` atribute to the `envth.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      envs-in = attrByPath ["env-addEnvs"] [] super;
      update = fix-envth-with envs-in;
      envs-added = if envs-in == [] then {} else update.envs-added;
      envs = envth.envs // envs-added ;
    in
      { env-addEnvs=null;
        passthru =  super.passthru // {
          inherit envs envs-added;
        };
      };


}
