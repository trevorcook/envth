{envth, lib, callPackage}: with lib; with builtins; with envth.lib;
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
            let env = callEnv (envth.override { envs = envs0 // self; }) f;
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
        let env = callEnv envth env_;
            envs = envth.envs // env.envs-added // (setAttrByPath [env.name] env);
            /* envs = env.envs // (setAttrByPath [env.name] env); */
        in envth.override { inherit envs; };
    in foldl' make-new envth ;

  # Overlay that adds `addEnvs` atribute to the `envth.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      envs-in = attrByPath ["addEnvs"] [] super;
      #envs-orig = envth.envs;
      update = fix-envth-with envs-in;
      envs-added = if envs-in == [] then {} else update.envs-added;
      envs = envth.envs // envs-added ;
    in
      { passthru =  super.passthru // {
          inherit envs envs-added;# envs-orig;
        };
      };


  # The below are two other implementations of this file. I was trying to
  # work around the circular dependencies problem of `addEnv`, noted above.
  /* WORKING WITH (fix extends envth) doesn't solve problem.
  #isPath = v: builtins.typeOf v == "path";
  mkEnvs = envth: x:
      let
        env = callEnv envth x;
        env-envs = concatMap (mkEnvs envth) env.passthru.envs-in;
      in [{ name = env.name; value = env; }] ++ env-envs;
  # Expand envth to include the list of environments. This uses a fixed
  # point to allow mutually dependent environments to be added.
  fix-envth-with = env-list:
    let
      envth' = fix (extends extend-envth (_: envth));
      extend-envth = self: super:
        let
          envs-added = concatMap (mkEnvs self) env-list;
          envs-extra = listToAttrs envs-added;
        in envth.override { envs = super.envs // envs-extra;};
      envs-added = concatMap (mkEnvs envth') env-list;
    in { envth = envth'; inherit envs-added; };

  # Exported utility for use with `envth.addEnvs`
  addEnvs = env-list: (fix-envth-with env-list).envth;

  # Overlay that adds `addEnvs` atribute to the `envth.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      # envth' = envth.override { envs = envs-all; };
      envs-in = attrByPath ["addEnvs"] [] super;
      update = fix-envth-with envs-in;
      envs-added = update.envs-added;
      envs-all = update.envth.envs;
      envs-extra = listToAttrs envs-added;
    in
      { passthru =  super.passthru // {
          inherit envs-in envs-added envs-extra;
          envs-added' = map (x: x.name) envs-added;
          envs = envs-all;
          #inherit envth envth';
        };
      }; */


#ORIGINAL
  #isPath = v: builtins.typeOf v == "path";
  /* mkEnvs = envth: x:
      let
        env = callEnv envth x;
        env-envs = concatMap (mkEnvs envth) env.passthru.envs-in;
      in [{ name = env.name; value = env; }] ++ env-envs; */
  /* # Expand envth to include the list of environments. This uses a fixed
  # point to allow mutually dependent environments to be added.
  fix-envth-with = env-list:
    let
      envth' = fix extend-envth (_: envth);
      # self and super are `envth`s
      extend-envth = self: super:
        let
          envs-added = concatMap (mkEnvs self) env-list;
          envs-extra = listToAttrs envs-added;
        in envth.override { envs = super.envs // envs-extra;};
      envs-added = concatMap (mkEnvs envth') env-list;
    in { envth = envth'; inherit envs-added; };

  # Exported utility for use with `envth.addEnvs`
  addEnvs = env-list: (fix-envth-with env-list).envth;

  # Overlay that adds `addEnvs` atribute to the `envth.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      # envth' = envth.override { envs = envs-all; };
      envs-in = attrByPath ["addEnvs"] [] super;
      update = fix-envth-with envs-in;
      envs-added = update.envs-added;
      envs-all = update.envth.envs;
      envs-extra = listToAttrs envs-added;
    in
      { passthru =  super.passthru // {
          inherit envs-in envs-added envs-extra;
          envs-added' = map (x: x.name) envs-added;
          envs = envs-all;
          #inherit envth envth';
        };
      };*/
}
