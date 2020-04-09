{stdenv, envth, lib}:
with lib;
with envth.resources;
with envth.lib;
with envth.init-attrs;
with envth.init-env;
with envth.builder;
with envth.imports;
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
      f' = composeExtensions f (add-drv-path base);
    in final;
}
