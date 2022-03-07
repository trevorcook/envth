{fname,lib,extras,envth}:
with builtins; with lib; with envth.lib.resources;

attrs_@{name,env-varsets?{},envlib?{},ENVTH_RESOURCES?no-resources
       ,imports?[], ...}:
let
  array-arg =  [{name="array";desc="The name of an associative array";}];
  setsarg = {name="varset"; choice=attrNames varsets;};
  varsets = if isAttrs env-varsets then env-varsets else {};
  show-attrs-with-sep = f : sep: attrs:
    concatStringsSep sep (mapAttrsToList f attrs);
  mkCase = f: n: vals: ''
    ${n})
      ${ f n vals }
      ;;
    '';
  sets-case = f: s:
    ''case $1 in
      ${ show-attrs-with-sep (mkCase f) "" s }
      esac
      '';
  attrs-pre = filterAttrs isNotEnvthVar attrs_.passthru.attrs-pre;
  envs-imported = attrByPath ["passthru" "envs-imported"] [] attrs_;
  /* attrs-resources = filterAttrs (_: isEnvSrc) attrs_; */
  attrs-resources = ENVTH_RESOURCES.resources;
  attrs-resources-twopaths =
    let esc = x: x; in
    mapAttrs (n: v: "${esc v.store} ${esc v.local}") attrs-resources;
  isNotEnvthVar = n: v: ! (isEnvthVar n v);
  isEnvthVar = n: v: hasPrefix "ENVTH" n || hasPrefix "env-" n ||
      (any (n': n == n') ["envlib" "passthru" "shellHook" "paths"]) ;

  show-attrs-as-assocArray = attrs:
    "( ${show-attrs-with-sep show-assocArray-value " " attrs} )";
  show-assocArray-value = name: value: ''[${name}]="${toString value}"'';

  pass-flags = concatStringsSep " "
    ["\${current:+--current}"
     "\${changed:+--changed}"
     "\${namesonly:+--names-only}"
     ];
  opt-def = {
    current.desc="Current values of keys as environment variables.";
    current.set="current";
    changed.desc="The current values of changed variables.";
    changed.set="changed";
    names-only.desc="Only print the names of variables set.";
    names-only.set="namesonly";
    array.desc="Set the supplied array";
    array.arg = true;
    array.set = "arrayname";
    to.desc = "Copy to directory";
    to.set = "copyto";
    to.arg = true;
    dryrun.desc = "Only say what would be done.";
    dryrun.set = "dryrun";


  };
in


{
  desc = "Query and Control some aspects of the environment.";

  commands.resource = {
    desc = "Show resources associated with environment.";
    opts = with opt-def; { inherit current changed array names-only; };
    hook = ''
      if [[ -n $arrayname ]]; then
        eval $arrayname='${ show-attrs-as-assocArray attrs-resources-twopaths }'
      else
        declare -A vars=${ show-attrs-as-assocArray attrs-resources-twopaths }
        envth array-vars show ${pass-flags} vars
      fi
        '';
  };
  /* commands.localize-old = {
    desc = ''For recreating original source environment relative to a directory.'';
    opts = with opt-def; { inherit to; };
    hook = ''
      copyto="''${copyto:=$(envth home-dir)}"
      mkdir -p $copyto
      echo "%% Making Local Resources in $copyto %%%%%%%%%%%%%%%%%%%%%%%"
      declare -a arr
      arr=( ${ENVTH_RESOURCES} )
      for i in "''${arr[@]}"; do
        envth copy-store --to "$copyto" $i
      done
      '';
      }; */

  commands.localize = {
          desc = ''Copy "mkSrc" resources from nix store. Expects zero or more resource names as arguments. Zero arguments implies all.'';
          opts = with opt-def; { inherit to dryrun; };
          hook = ''
            dryrun="''${dryrun:+--dryrun}"
            copyto="''${copyto:+--to=$copyto}"
            #declare -p dryrun copyto

            declare -A rsrcs
            envfun-${name} resource --array=rsrcs
            if [[ $# == 0 ]]; then
              for resource in ''${!rsrcs[@]}; do
                envth copy-store $dryrun $copyto ''${rsrcs[$resource]}
              done
            else
              for resource in "$@"; do
                envth copy-store $dryrun $copyto ''${rsrcs[$resource]}
              done
            fi
            '';
        };


  commands.varsets = {
    desc = "Manipulate environment variable sets defined in env-varsets";
    commands.set = {
      desc = "Set the varset keys to environment variables.";
      args = if varsets!={} then [setsarg] else [];
      hook = let
        do-set = n: v:
          if isNull v then
            "unset ${n}"
          else '''declare -xg ${n}="${toString v}"'';
      in
        sets-case (_: show-attrs-with-sep do-set "\n") varsets;
      };
    commands.list = {
      desc = "Show available varsets.";
      hook = ''echo ${show-attrs-with-sep (n: _: n) " " varsets}'';
    };
    commands.show = {
      desc = "Show the value assignments of a varset.";
      opts = with opt-def; {inherit current changed names-only;};
      args = if varsets!={} then [setsarg] else [];
      hook = ''
        ${sets-case
           ( n: s : ''declare -A vars=${ show-attrs-as-assocArray s }'')
           varsets }
        envth array-vars show ${pass-flags} vars
        '';
    };
  };


  commands.vars = {
    desc = "Show environment variables set by mkEnvironment definition.";
    opts = with opt-def; {inherit current changed names-only;};
    hook = ''
        declare -A vars=${ show-attrs-as-assocArray attrs-pre }
        envth array-vars show ${pass-flags} vars
        '';
  };

  commands.lib = {
    desc = "Show functions exported by this environment.";
    hook = ''
      declare sep=" "
      echo "${concatStringsSep "\${sep}" (attrNames (extras // envlib ))}"
      '';
  };
  commands.imports = {
    desc = "Show environments imported by this environment.";
    hook = ''
      echo "${concatStringsSep " " (map (i: i.name) envs-imported)}"
      '';
  };



}


    /* commands.caller = {
      hook = ''
        if attrs ? passthru.env-caller then
        { "${name}-caller" = ''
          echo "${show-caller attrs.passthru.env-caller}"
          '';
        }
        ''; */
