{ envth, lib,  writeTextFile, symlinkJoin, pandoc, runCommand,
  writeScriptBin, tree, metafun }:
with builtins;
with lib;
let # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls)); in
rec {
  mkShellFunctions = attrs :
    concatStrings (mapAttrsToList mkShellFunction attrs);
  mkShellFunction = with metafun; name: value: ''
      ${name}(){
      ${mkCommand name value}
      }
      export -f ${name}
      ${ if isAttrs value then ''
      _${name}-complete(){
      ${mkCommandCompletion name value}
      }
      export -f _${name}-complete
      complete -F _${name}-complete ${name}
      ''
      else ""}
      '';

  mk-envlib-doc = name: lib-file: runCommand "${name}-envlib-doc" {} ''
    mkdir -p $out/doc/html
    ${pandoc}/bin/pandoc -f markdown -s --metadata pagetitle=${name} \
      <(  cat <( echo '```bash' ) \
      ${lib-file}  \
      <( echo '```' ) ) \
      -o $out/doc/html/${name}-envlib.html
    '';

  mk-envlib-sh = name: lib: writeTextFile  {
    name = "${name}-envlib";
    text = mkShellFunctions lib;
    executable = true;
    destination = "/lib/${name}-envlib.sh";
  };

  mkLibsDocDir = name: libs: runCommand "${name}-importLibs" { inherit libs; } ''
    #NOTE: This command will fail (probably) for env names with spaces.
    mkdir -p $out/doc/html
    for l in $libs; do
      for f in $( ls $l/doc/html/. ); do
        if [[ "$f" != index.html ]]; then
          ln -s "$l/doc/html/$f" "$out/doc/html/$f"
        fi
      done
    done
    ${tree}/bin/tree -H "$out/doc/html/" -L 1 --noreport --charset utf-8 \
      $out/doc/html/. > $out/doc/html/index.html
    '';

  mkEnvLibExtras = attrs@{ name, envlib ? {}, ENVTH_RESOURCES ? ""
                         , env-varsets?{}, ...}:
    let
      attrs' = filterAttrs (n: v: all (x: n != x)
                    ["envlib" "passthru" "ENVTH_DRV" "shellHook" "paths"
                     "env-caller" "env-varsets"])
                    attrs.passthru.attrs-pre;
      extras = {
      "envfun-${name}" = import ./env-metafun.nix
        {fname = "envfun-${name}"; inherit lib extras envth;}
        attrs;
      };
  in extras;

  mkEnvLibText = attrs@{ envlib?{},...} :
    mkShellFunctions ((mkEnvLibExtras attrs) // envlib);
  mkEnvLib = attrs@{ name,envlib?{},... }:
    mk-envlib-sh name ((mkEnvLibExtras attrs) // envlib);

  show-caller = env-caller: if isAttrs env-caller then
      show-vars-default env-caller
    else toString env-caller;

  show-attrs-with-sep = f : sep: attrs:
    concatStringsSep sep (mapAttrsToList f attrs);
  show-attrs-as-assocArray = attrs:
    "( ${show-attrs-with-sep show-assocArray-value " " attrs} )";
  show-attrs-as-nix-set = attrs:
    "{ ${show-attrs-with-sep show-nix-declaration " " attrs} }";

  show-nonPaths = x: if typeOf x == path then x else toString x;
  show-assocArray-value = name: value: ''[${name}]="${value}"'';
  show-nix-declaration = name: value: ''${name} = ${value};'';

  make-vars-string = f: attrs:
    concatStringsSep "\n" (mapAttrsToList f attrs);
  export-vars = make-vars-string (n: v: "export ${n}=${v}");
  show-vars = show-vars-current;
  show-vars-current = make-vars-string (n: v: "${n} = \${"+"${n}}");
  show-vars-default = make-vars-string (n: v: "${n} = ${builtins.toString v}");

  make-envlib = self: super@{import_libs ? [], name, env-varsets?null,...}:
    let
      import_libs_out = uniquer ( import_libs ++ [envlib] );
      envlib = mkEnvLib (super );
      /* lib_doc = mkShellLib-doc name envlib; */
      sourceLib = l:
      ''source ${l}/lib/*
        '';
      /* envlib-doc = if null == attrByPath ["env-opts" "envlib-doc"] null super then
         {}
       else
         { libs_doc = mkLibsDocDir name import_libs_out; }; */
    in {
      env-varsets = if isNull env-varsets then
        null
        else {__toString=_:null;} // env-varsets;
      inherit envlib;
      import_libs = import_libs_out;
      importLibsHook = concatMapStrings sourceLib import_libs_out;
      passthru = super.passthru // {  inherit envlib;
                                      };
    } ;
}
