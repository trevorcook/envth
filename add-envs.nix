{env-th, lib, callPackage}: with lib;
let
  isPath = v: builtins.typeOf v == "path";
  mkEnvs = env-th: x:
      let
        env = callEnv env-th x;
        env-envs = concatMap (mkEnvs env-th) env.passthru.envs-in;
      in [{ name = env.name; value = env; }] ++ env-envs;
  callEnv = env-th: x:
      if isPath x then callPackage x { inherit env-th; } else x;
in rec {
  # Common utility used in subsequent definitions. It loads environments,
  # all environments loaded with `add-env` overlay, and provides an updated
  # env-th with the resulting environments.
  update-env-th-with = env-list:
    let
      env-th' = env-th.override { envs = envs-all; };
      envs-added = listToAttrs (concatMap (mkEnvs env-th') env-list);
      envs-all = env-th.envs // envs-added;
    in { env-th = env-th'; inherit envs-added; };

  # Exported utility for use with `env-th.addEnvs`
  addEnvs = env-list: (update-env-th-with env-list).env-th;

  # Overlay that adds `envs` atribute to the `env-th.env` attribute of imported
  # environments.
  add-envs = self: super:
    let
      /* env-th' = env-th.override { envs = envs-all; }; */
      envs-in = attrByPath ["envs"] [] super;
      update = update-with envs-in;
      envs-out = update.envs-added;
      envs-all = update.env-th.envs;
      envs-extra = listToAttrs envs-out;
    in
      { passthru =  super.passthru // {
          inherit envs-extra envs-in envs-out;
          envs-out' = map (x: x.name) envs-out;
          envs = envs-all;
          /* inherit env-th env-th'; */

        };
      };
}
