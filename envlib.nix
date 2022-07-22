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

  /* mkEnvLib = attrs@{ name,envlib?{},... }:
    mk-envlib-sh name ((mkEnvLibExtras attrs) // envlib); */
  /* mk-envlib-sh = name: lib: writeTextFile  {
    name = "${name}-envlib";
    text = mkShellFunctions lib;
    executable = true;
    destination = "/lib/${name}-envlib.sh";
  }; */
  mkEnvLib = attrs@{ name,envlib?{},... }: writeTextFile  {
    name = "${name}-envlib";
    text = mkShellFunctions envlib + (mkEnvUtilFcn attrs);
    executable = true;
    destination = "/lib/${name}-envlib.sh";
  };


  # This function made markdown for the envlib sources. After move to
  # metafun, this was taken out.h
  /* mkLibsDocDir = name: libs: runCommand "${name}-importLibs" { inherit libs; } ''
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
    ''; */
  /* mk-envlib-doc = name: lib-file: runCommand "${name}-envlib-doc" {} ''
    mkdir -p $out/doc/html
    ${pandoc}/bin/pandoc -f markdown -s --metadata pagetitle=${name} \
      <(  cat <( echo '```bash' ) \
      ${lib-file}  \
      <( echo '```' ) ) \
      -o $out/doc/html/${name}-envlib.html
    ''; */
  /* mkEnvLibExtras = attrs@{ name, envlib ? {}, ENVTH_RESOURCES ? ""
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
  in extras; */
  mkEnvUtilFcn = attrs@{ name, envlib ? {}, ENVTH_RESOURCES ? ""
                         , env-varsets?{}, ...}:
    let
      fcn-name = "envfun-${name}";
      comp-fcn-name = "_${fcn-name}-complete";
      #cmd-name = "envcmd-${name}";
      #comp-name = "_${cmd-name}-complete";
      cmd-name = fcn-name;
      comp-name = comp-fcn-name;
      def = envUtilDef attrs;
      cmd = writeScriptBin cmd-name (metafun.mkCommand cmd-name def);
      comp = writeScriptBin comp-name (metafun.mkCommandCompletion comp-name def);
      in ''
          ${fcn-name}(){
            source ${cmd}/bin/${cmd-name} "$@"
          }
          ${comp-fcn-name}(){
            source ${comp}/bin/${comp-name} "$@"
          }
          export -f ${fcn-name}
          export -f ${comp-fcn-name}
          complete -F ${comp-fcn-name} ${fcn-name}
          '';

  envUtilDef = attrs@{ name, ... }: import ./env-metafun.nix
    {fname = "envfun-${name}"; inherit lib envth;} attrs;

  # show-caller = env-caller: if isAttrs env-caller then
  #     show-vars-default env-caller
  #   else toString env-caller;

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
      sourceLib = l: ''
        source ${l}/lib/*
        '';
    in {
      inherit envlib;
      env-varsets = if isNull env-varsets then
        null
        else {__toString=_:null;} // env-varsets;
      import_libs = import_libs_out;
      importLibsHook = concatMapStrings sourceLib import_libs_out;
      passthru = super.passthru // {  inherit envlib;
                                      };
    } ;
}
