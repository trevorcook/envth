{fname,lib}: attrs_@{name,env-varsets?{},...}:
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
  isNotEnvthVar = n: v: ! (isEnvthVar n v);
  isEnvthVar = n: v: hasPrefix "ENVTH" n || hasPrefix "env-" n ||
      (any (n': n == n') ["envlib" "passthru" "shellHook" "paths"]) ;

  show-attrs-as-assocArray = attrs:
    "( ${show-attrs-with-sep show-assocArray-value " " attrs} )";
  show-assocArray-value = name: value: ''[${name}]="${value}"'';

in


{
  desc = "Query and Control some aspects of an environment";

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
      desc = "Show the value assignments of a set.";
      opts = {
        current = {
          desc = "Show the current values of the varset variables";
          hook = ''declare current=true'';
        };

      };
      args = if varsets!={} then [setsarg] else [];
      hook = sets-case (n: v:
        ''{ [[ -n $current ]] && { declare -p ${n}; true;}; } || echo "${n}=\"${toString v}\""'' );
    };
  };


  commands.vars = {
    desc = "Show environment variables set by mkEnvironment definition.";
    opts = {
      current.desc="Current values";
      current.hook="declare current=true";
      names-only.desc="Only print the names of variables set.";
      names-only.hook="declare namesonly=true";
    };
    hook = ''
        declare -A vars=${ show-attrs-as-assocArray
                             (mapAttrs (_: toString) attrs-pre)}
        declare -p vars
        if [[ $namesonly == true ]]; then
          echo ''${!vars[@]}
        elif [[ $current == true ]]; then
          for key in "''${!vars[@]}"; do
              echo "$key=$(eval echo \$$(echo $key))"
          done
        elif [[ -z changed ]]; then
          for key in "''${!vars[@]}"; do
            curval="$(eval echo \$$(echo $key))"
            origval="''${vars[$key]}"
            if [[ $curval != $origval ]]; then
              echo "$key = $curval ($origval)"
            fi
          done
        else
          for key in "''${!vars[@]}"; do
            echo "$key=''${vars[$key]}"
          done
        fi
        '';

  };


}
