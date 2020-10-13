{runCommand, callPackage, env-th,lib,stdenv,coreutils,writeText,env0}: rec {
  # add-reloader adds a derivation that can be used to call an
  # environment with callPackage. This is used by env-0.lib.env-reload
  add-reloader = self: super: {
    ENVTH_CALLER = (lib.makeOverridable caller {});
    /* ENVTH_CALLER = (caller {}).drvPath; */
    /* ENVTH_CALLER = env0.drvPath; */
    };
  /* caller = { definition?"" }: runCommand "env-th-caller" {
    passthru = rec {
      call-env = callEnvPackage definition {};
      callEnvPackage = pk: over:
        let
          over' = { inherit env-th; } // over;
          pk' = if builtins.typeOf pk == "path"
                then import pk else pk;
        in if lib.isFunction pk' then callPackage pk' over' else pk';
      };
    } ''touch $out''; */
  caller = { definition?"" }: stdenv.mkDerivation {
    name = "env-th-caller";
    shellHook = "";
    builder = writeText "touch-out" ''${coreutils}/bin/echo $out > $out'';
    passthru = rec {
      inherit env0;
      /* callover = caller.override */
      callenv = callEnvPackage definition {};
      #callenv = callEnvPackage definition {};
      callEnvPackage = pk: over:
        let
          over' = { inherit env-th; } // over;
          pk' = if builtins.typeOf pk == "path"
                then import pk else pk;
        in if lib.isFunction pk' then callPackage pk' over' else pk';
      };
    };
  /* caller = { definition?"" }: env-th.mkEnvironment {
    name = "env-th-caller";
    inherit definition;
    passthru = rec {
      callenv = { definition?"" }: callEnvPackage definition {};
      #callenv = callEnvPackage definition {};
      callEnvPackage = pk: over:
        let
          over' = { inherit env-th; } // over;
          pk' = if builtins.typeOf pk == "path"
                then import pk else pk;
        in if lib.isFunction pk' then callPackage pk' over' else pk';
      };
    }; */
}
