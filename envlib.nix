{ envth, lib,  writeTextFile, symlinkJoin, pandoc, runCommand,
  writeScriptBin, tree, metafun }:
with builtins;
with lib;
let # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls)); in
rec {

  # make the environment functionality assiciated with the `envlib` attribute.
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

  # The text file associated with the envlib function definitions
  mkEnvLib = attrs@{ name,envlib?{},... }: writeTextFile  {
    name = "${name}-envlib";
    text = mkShellFunctions envlib + (mkEnvUtilFcn attrs);
    executable = true;
    destination = "/lib/${name}-envlib.sh";
  };

  mkEnvUtilFcn = attrs@{ name, envlib ? {}, ENVTH_RESOURCES ? ""
                         , env-varsets?{}, ...}:
    let
      fcn-name = "envfun-${name}";
      comp-fcn-name = "_${fcn-name}-complete";
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

  # The automatically generated "envfun-${name}" that reports some environment information.
  envUtilDef = attrs@{ name, ... }: envth.lib.make-envfun
    {fname = "envfun-${name}"; inherit lib envth;} attrs;



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

}
