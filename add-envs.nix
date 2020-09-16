{env-th, lib, callPackage}: with lib; with builtins;
let
  #isPath = v: builtins.typeOf v == "path";
  mkEnvs = env-th: x:
      let
        env = callEnv env-th x;
        env-envs = concatMap (mkEnvs env-th) env.passthru.envs-in;
      in [{ name = env.name; value = env; }] ++ env-envs;
  callEnv = env-th: x:
      if isPath x then callPackage x { inherit env-th; } else x;
  diffAttrs = a: b: removeAttrs a (attrNames b);
in rec {

  # Common utility used in subsequent definitions. It loads environments,
  # all environments loaded with `add-env` overlay, and provides an updated
  # env-th with the resulting environments.
  update-env-th-with = env-list:
    let
      envs0 = env-th.envs;
      envs-added = fix (extends extend-envs (_: {}));
      extend-envs = self: super:
        let
          addNewEnv = env: envs:
            let env' = attrByPath [env.name] {} envs;
            in if env' == env then envs else
                  envs // (setAttrByPath [env.name] env);
          envs = foldr add-env super env-list;
          add-env = f: envs:
            let env = callEnv (env-th.override { envs = envs0 // self; }) f;
            in envs // env.envs-added // (setAttrByPath [env.name] env);
        in envs;

    in { env-th = env-th.override { envs = envs0 // envs-added; };
         inherit envs-added; };

  # Exported utility for use with `env-th.addEnvs`
  addEnvs = env-list: (update-env-th-with env-list).env-th;

  # Overlay that adds `addEnvs` atribute to the `env-th.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      envs-in = attrByPath ["addEnvs"] [] super;
      update = update-env-th-with envs-in;
      envs-added = update.envs-added;
      envs = env-th.envs // envs-added ;
    in
      { passthru =  super.passthru // {
          inherit envs envs-added;
        };
      };
  /* WORKING WITH (fix extends env-th) doesn't solve problem.
  # Common utility used in subsequent definitions. It loads environments,
  # all environments loaded with `add-env` overlay, and provides an updated
  # env-th with the resulting environments.
  update-env-th-with = env-list:
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
  addEnvs = env-list: (update-env-th-with env-list).env-th;

  # Overlay that adds `addEnvs` atribute to the `env-th.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      # env-th' = env-th.override { envs = envs-all; };
      envs-in = attrByPath ["addEnvs"] [] super;
      update = update-env-th-with envs-in;
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
  /* # Common utility used in subsequent definitions. It loads environments,
  # all environments loaded with `add-env` overlay, and provides an updated
  # env-th with the resulting environments.
  update-env-th-with = env-list:
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
  addEnvs = env-list: (update-env-th-with env-list).env-th;

  # Overlay that adds `addEnvs` atribute to the `env-th.envs` attribute of
  # imported environments.
  add-envs = self: super:
    let
      # env-th' = env-th.override { envs = envs-all; };
      envs-in = attrByPath ["addEnvs"] [] super;
      update = update-env-th-with envs-in;
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
