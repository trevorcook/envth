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

  # Each extension represents a step of processing. Each extension has a type,
  # `extension :: self -> super -> attrs`, where all the entities represent
  # the attribute set that eventually gets passed to `mkDerivation`. `self` is
  # that final attribute set. It can be used as an input as long as the used
  # attributes don't define themselves. Super is the current state of the input
  # attributes. `attrs` are the attributes added/modified in the extension.
  env-extensions = [ (save-attrs-as "attrs-pre")
                     add-envs
                     set-default-build-dir
                     gather-resources
                     add-imports
                     make-builder
                     make-env-lib
                     (save-attrs-as "attrs-post")
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
