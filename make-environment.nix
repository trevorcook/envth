{stdenv, envth, lib}:
with lib;
with envth.lib.resources;
with envth.lib.envlib;
with envth.lib.inits;
with envth.lib.builder;
with envth.lib.imports;
with envth.lib.add-envs;
with envth.lib.caller;
rec
{
  # Each extension represents a step of processing. Each extension has a type,
  # `extension :: self -> super -> attrs`, where all the entities represent
  # the attribute set that eventually gets passed to `mkDerivation`. `self` is
  # that final attribute set. It can be used as an input as long as the used
  # attributes don't define themselves. Super is the current state of the input
  # attributes. `attrs` are the attributes added/modified in the extension.
  env-extensions = [ (save-attrs-as "attrs-pre")
                     set-default-build-dir
                     gather-resources
                     add-caller
                     add-envs
                     add-imports
                     make-builder
                     make-envlib
                     (save-attrs-as "attrs-post")
                     init-env
                    ];

  env0-extensions = [ (save-attrs-as "attrs-pre")
                       make-builder
                       make-envlib
                       (save-attrs-as "attrs-post")
                    ];

  process-attrs = foldl composeExtensions (_: super: super);

  mkEnvironment = mkEnvironmentWith env-extensions ;
  mkEnvironmentWith = exts-in: attrs:
    let
      f = process-attrs exts-in;
      proc = exts: fix (extends exts (_: attrs));
      base = stdenv.mkDerivation (proc f);
      final = stdenv.mkDerivation (proc f');
      f' = composeExtensions (add-drv-path base) f;
    in final;
}
