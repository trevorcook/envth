{env-th, lib, callPackage}: with lib; with builtins; with env-th.lib;
rec {

  # Expand env-th to include the list of environments. This uses a fixed
  # point to allow mutually dependent environments to be added.
  fix-env-th-with = env-list:
    let
      envs0 = env-th.envs;
      envs-added = fix (extends extend-envs (_: {}));
      extend-envs = self: super:
        let
          envs = foldr add-env super env-list;
          add-env = f: envs:
            let env = callEnv (env-th.override { envs = envs0 // self; }) f;
            in envs // env.envs-added // (setAttrByPath [env.name] env);
        in envs;

    in { env-th = env-th.override { envs = envs0 // envs-added; };
         inherit envs-added; };

  # Exported utility for use with `env-th.addEnvs`
  addEnvs = addEnvs-nonfix;
  # This was the original addEnvs utility. However, interactions with
  # add-envs caused the possiblilty of circular import cycles.
  addEnvs-fix = env-list: (fix-env-th-with env-list).env-th;
  # This will add environments to `env-th`. Environments are added in order.
  # Later environments may depend on earlier envioronments.
  addEnvs-nonfix =
    let
      make-new = env-th: env_:
        let env = callEnv env-th env_;
            /* envs = env-th.envs // (setAttrByPath [env.name] env); */
            envs = env.envs // (setAttrByPath [env.name] env);
        in env-th.override { inherit envs; };
    in foldl' make-new env-th ;

  # Overlay that adds `addEnvs` atribute to the `env-th.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      envs-in = attrByPath ["addEnvs"] [] super;
      envs-orig = env-th.envs;
      update = fix-env-th-with envs-in;
      envs-added = if envs-in == [] then {} else update.envs-added;
      envs = env-th.envs // envs-added ;
    in
      { passthru =  super.passthru // {
          inherit envs envs-added envs-orig;
        };
      };


  # The below are two other implementations of this file. I was trying to
  # work around the circular dependencies problem of `addEnv`, noted above.
  /* WORKING WITH (fix extends env-th) doesn't solve problem.
  #isPath = v: builtins.typeOf v == "path";
  mkEnvs = env-th: x:
      let
        env = callEnv env-th x;
        env-envs = concatMap (mkEnvs env-th) env.passthru.envs-in;
      in [{ name = env.name; value = env; }] ++ env-envs;
  # Expand env-th to include the list of environments. This uses a fixed
  # point to allow mutually dependent environments to be added.
  fix-env-th-with = env-list:
    let
      env-th' = fix (extends extend-env-th (_: env-th));
      extend-env-th = self: super:
        let
          envs-added = concatMap (mkEnvs self) env-list;
          envs-extra = listToAttrs envs-added;
        in env-th.override { envs = super.envs // envs-extra;};
      envs-added = concatMap (mkEnvs env-th') env-list;
    in { env-th = env-th'; inherit envs-added; };

  # Exported utility for use with `env-th.addEnvs`
  addEnvs = env-list: (fix-env-th-with env-list).env-th;

  # Overlay that adds `addEnvs` atribute to the `env-th.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      # env-th' = env-th.override { envs = envs-all; };
      envs-in = attrByPath ["addEnvs"] [] super;
      update = fix-env-th-with envs-in;
      envs-added = update.envs-added;
      envs-all = update.env-th.envs;
      envs-extra = listToAttrs envs-added;
    in
      { passthru =  super.passthru // {
          inherit envs-in envs-added envs-extra;
          envs-added' = map (x: x.name) envs-added;
          envs = envs-all;
          #inherit env-th env-th';
        };
      }; */


#ORIGINAL
  #isPath = v: builtins.typeOf v == "path";
  /* mkEnvs = env-th: x:
      let
        env = callEnv env-th x;
        env-envs = concatMap (mkEnvs env-th) env.passthru.envs-in;
      in [{ name = env.name; value = env; }] ++ env-envs; */
  /* # Expand env-th to include the list of environments. This uses a fixed
  # point to allow mutually dependent environments to be added.
  fix-env-th-with = env-list:
    let
      env-th' = fix extend-env-th (_: env-th);
      # self and super are `env-th`s
      extend-env-th = self: super:
        let
          envs-added = concatMap (mkEnvs self) env-list;
          envs-extra = listToAttrs envs-added;
        in env-th.override { envs = super.envs // envs-extra;};
      envs-added = concatMap (mkEnvs env-th') env-list;
    in { env-th = env-th'; inherit envs-added; };

  # Exported utility for use with `env-th.addEnvs`
  addEnvs = env-list: (fix-env-th-with env-list).env-th;

  # Overlay that adds `addEnvs` atribute to the `env-th.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      # env-th' = env-th.override { envs = envs-all; };
      envs-in = attrByPath ["addEnvs"] [] super;
      update = fix-env-th-with envs-in;
      envs-added = update.envs-added;
      envs-all = update.env-th.envs;
      envs-extra = listToAttrs envs-added;
    in
      { passthru =  super.passthru // {
          inherit envs-in envs-added envs-extra;
          envs-added' = map (x: x.name) envs-added;
          envs = envs-all;
          #inherit env-th env-th';
        };
      };*/
}
