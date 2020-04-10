{stdenv, env-th, lib}:
with lib;
with env-th.resources;
with env-th.lib;
with env-th.init-attrs;
with env-th.init-env;
with env-th.builder;
with env-th.imports;
rec
{

  env-extensions = [ save-attrs
                     set-default-build-dir
                     gather-resources
                     add-imports
                     make-builder
                     make-env-lib
                     init-env
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
