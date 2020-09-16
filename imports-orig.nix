{callPackage, lib, env-th}: with builtins; with lib;
with env-th.lib.init-attrs;
let
  isPath = v: builtins.typeOf v == "path";
in
rec
  {

    merge-import = x: accum@{ import_names ? [],
                              import_libs ? [],
                              import_shellHooks ? [],
                              import_buildInputs ? [],
                              ...}:
    let
      imp = if isPath x then callPackage x {inherit env-th;} else x;
      attrMaybe = def: p: s: if hasAttrByPath p s
                               then getAttrFromPath p s
                               else def;

    in
      imp.passthru.attrs // accum // {
        import_names = [imp.name] ++ import_names;
        import_buildInputs =  (attrMaybe [] ["passthru" "attrs" "buildInputs"] imp)
                           ++ (attrMaybe [] [ "import_buildInputs" ] imp)
                           ++ import_buildInputs;
        import_libs = (attrMaybe [] ["import_libs"] imp)
                    ++ [(attrMaybe [] ["lib"] imp)]
                    ++ import_libs;
        import_shellHooks = (attrMaybe [""] ["passthru" "attrs" "shellHooks"] imp)
                          ++ import_shellHooks;
      };
    mkImportAttrs = orig@{buildInputs?[], ...}:
                    mg@{import_libs ? [], import_buildInputs ? [],...}:
      let
        f = l: "source ${l}\n";
      in
        { importLibsHook = concatMapStrings f import_libs ;
          buildInputs = buildInputs ++ import_buildInputs; };

    add-imports = self: attrs:
      if attrs ? imports && attrs.imports != [] then
        let
          mg = foldr merge-import {} attrs.imports;
        in
          (diffAttrs mg attrs)
          // (mkImportAttrs attrs mg)
      else
        {};
  }
