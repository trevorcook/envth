{fname,lib,extras,envth}:
attrs_@{name,env-varsets?{},envlib,ENVTH_RESOURCES ? "",...}:
with builtins; with lib;
let
  setsarg = {name="varset";type=attrNames varsets;};
  varsets = if isAttrs env-varsets then env-varsets else {};
  show-attrs-with-sep = f : sep: attrs:
    concatStringsSep sep (mapAttrsToList f attrs);
  mkCase = f: n: vals: ''
    ${n})
      ${show-attrs-with-sep f "\n" vals }
      ;;
    '';
  sets-case = f:
    ''case $1 in
      ${ show-attrs-with-sep (mkCase f) "" varsets }
      esac
      '';
  attrs-pre = filterAttrs isNotEnvthVar attrs_.passthru.attrs-pre;
  attrs-resources = envth.lib.resources.filter-resources attrs_;
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
    current.desc="Current values";
    current.hook="declare current=true";
    changed.desc="The current values of changed variables.";
    changed.hook="declare changed=true";
    names-only.desc="Only print the names of variables set.";
    names-only.hook="declare namesonly=true";
    array.desc = "Show the varset as the values of an associative array";
    array.hook = ''declare array=true'';
    to.desc = "copy to directory";
    to.hook = _:''declare copyto="$1"'';
  };
in


{
  desc = "Query and Control some aspects of an environment";

  commands.resources = {
    desc = "Show resources associated with environment.";
    /* opts = {

    }; */
    hook = ''
        declare -A vars=${ show-attrs-as-assocArray attrs-resources }
        echo "$vars"
        declare -p vars
        #echo ${fname} array-vars vars
        #${fname} array-vars ${pass-flags} vars
        '';

  };

  commands.lib = {
    desc = "Show functions exported by this environment.";
    hook = ''
      declare sep=" "
      echo "${concatStringsSep "\${sep}" (attrNames (extras // envlib ))}"
      '';
  };

  commands.localize = {
    desc = ''For recreating original source environment relative to a
             directory.'';
    opts = opt-def.to;
    hook = ''
      copyto="''${copyto:=$(env-home-dir)}"
      mkdir -p $copyto
      echo "%% Making Local Resources in $copyto %%%%%%%%%%%%%%%%%%%%%%%"
      declare -a arr
      arr=( ${ENVTH_RESOURCES} )
      for i in "''${arr[@]}"; do
        env-cp-resource-to "$copyto" $i
      done
      '';
      };

    /* commands.caller = {
      hook = ''
        if attrs ? passthru.env-caller then
        { "${name}-caller" = ''
          echo "${show-caller attrs.passthru.env-caller}"
          '';
        }
        ''; */

  commands.varsets = {
    desc = "Manipulate environment variable sets defined in env-varsets";
    commands.set = {
      args = if varsets!={} then [setsarg] else [];
      hook = sets-case (n: v:
               if isNull v then
                 "unset ${n}"
               else "declare -xg ${n}=${toString v}");
      };
    commands.list = {
      desc = "Show available varsets.";
      hook = ''echo ${show-attrs-with-sep (n: _: n) " " varsets}'';
    };
    commands.show = {
      desc = "Show the value assignments of a varset.";
      opts = with opt-def; {inherit current changed array names-only;};
      args = if varsets!={} then [setsarg] else [];
      hook = ''
        if [[ -n $array ]]; then
          ${sets-case (n: v: ''echo -n ' [${n}]="${toString v}" ' '' )}
        else
          eval declare -A vars=( $( ${fname} varsets show --array $1 ) )
          ${fname} array-vars ${pass-flags} vars
        fi
        '';
    };
  };


  commands.vars = {
    desc = "Show environment variables set by mkEnvironment definition.";
    opts = with opt-def; {inherit current changed array names-only;};
    hook = ''
        declare -A vars=${ show-attrs-as-assocArray attrs-pre }
        ${fname} array-vars ${pass-flags} vars
        '';
  };


  commands.array-vars = {
    desc = "Show environment variables reflected by an array. This
           is a utility used in `vars` and `varsets`";
    opts = with opt-def; {inherit current changed array names-only;};
    args = [{name="array";desc="The name of an associative array";}];
    hook = ''
        declare temp=$(declare -pn $1)
        declare val
        declare -A vars
        eval "''${temp/$1=/vars=}"
        for key in "''${!vars[@]}"; do
          if [[ -n $current ]] ; then
            eval val=$(echo \$$(echo $key))
            echo "$key=$val"
          elif [[ -n $changed ]]; then
            eval val=$(echo \$$(echo $key))
            [[ $val != ''${vars[$key]} ]] && echo "$key=$val"
          elif [[ -n $namesonly ]]; then
            echo "$key"
          else
            val=''${vars[$key]}
            echo "[$key]=$val"
          fi
        done
        '';
  };


}
