{callPackage, lib, env-th}: with builtins; with lib;
with env-th.init-attrs;
let
  isPath = v: builtins.typeOf v == "path";
in
rec
  {

    merge-import = x: accum@{ import_names ? [],
                              import_libs ? [],
                              import_shellHooks ? [],
                              ...}:
     let
       imp = if isPath x then callPackage x {} else x;
       getShellHook = if imp ? passthru.attrs.shellHook then
                        imp.passthru.attrs.shellHook
                      else "NoShellHook";
       getImpLib = if imp ? import_libs then
                     imp.import_libs
                   else
                     [];
     in
      imp.passthru.attrs // accum // {
        import_names = [imp.name] ++ import_names;
        import_libs = getImpLib ++ [imp.lib] ++ import_libs;
        import_shellHooks = [getShellHook]
                          ++ import_shellHooks;
      };
    mkImportLibsHook = attrs@{import_libs ? [],...}:
      let
        f = l: "source ${l}\n";
      in
        attrs // { importLibsHook = concatMapStrings f import_libs ;};

    add-imports = self: attrs:
      if attrs ? imports && attrs.imports != [] then
        let
          mg = foldr merge-import {} attrs.imports;
        in
          diffAttrs (mkImportLibsHook mg) attrs
      else
        {};
  }
