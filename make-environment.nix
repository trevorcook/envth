{stdenv, env-th, lib}:
with lib;
with env-th.lib.resources;
with env-th.lib.shellLib;
with env-th.lib.init-attrs;
with env-th.lib.init-env;
with env-th.lib.builder;
with env-th.lib.imports;
with env-th.lib.add-envs;
rec
{

  env-extensions = [ save-attrs
                     set-default-build-dir
                     gather-resources
                     add-imports
                     make-builder
                     make-env-lib
                     init-env
                     add-envs
                    ];

  process-attrs =
    foldl composeExtensions (_: super: super) env-extensions;

  mkEnvironment = mkEnvironmentWith process-attrs;
  mkEnvironmentWith = f: attrs:
    let
      proc = exts: fix (extends exts (_: attrs));
      base = stdenv.mkDerivation (proc f);
      final = stdenv.mkDerivation (proc f');
      f' = composeExtensions (add-drv-path base) f;
    in final;
}
