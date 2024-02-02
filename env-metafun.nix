{lib,envth}:
with builtins; with lib; with envth.lib.resources;
rec {
  make-metafun-attrs = attrs_@{name,env-varsets?{},envlib?{},ENVTH_RESOURCES?no-resources
       ,imports?[],...}:
  let
    fname = "envfun-${name}";
    varsets = if isAttrs env-varsets then env-varsets else {};
    projects = attrByPath ["passthru" "projects"] {} attrs_;
    project_names = attrNames projects;
    attrs-pre = 
      let
        isNotEnvthVar = n: v: ! (isEnvthVar n v);
        isEnvthVar = n: v: 
          hasPrefix "ENVTH" n ||
          hasPrefix "env-" n ||
          (any (n': n == n') ["envlib" "envcmd" "passthru" "shellHook" "paths"]) ;
      in filterAttrs isNotEnvthVar attrs_.passthru.attrs-pre;
    envs-imported = attrByPath ["passthru" "envs-imported"] [] attrs_;
    envs-imported-declared = attrByPath ["passthru" "envs-imported-declared"] [] attrs_;
    envs-added = attrValues (attrByPath ["passthru" "envs-added"] {} attrs_);

    arg-def = {
      resource.desc = "The name of a specific resource.";
      resource.completion.hook = ''echo ${toString resource-names}'';
      project.desc = "The name of a declared project.";
      project.choice = project_names;
      varset.name = "varset";
      varset.choice = attrNames varsets;
      env.name="env"; 
      env.completion.hint = "<env>";
      env.completion.hook = ''echo "${show-envs-added}"'';
    };
    show-attrs-with-sep = sep: f: attrs:
      concatStringsSep sep (mapAttrsToList f attrs);  
    show-assocArray-value = name: value: ''[${name}]="${toString value}"'';
    show-envs-added = toString (map (i: i.name) envs-added);

    attrs-to-case = shVar: f: attrs:
      let 
        list = attrsToList attrs;
        f-pattern = item: item.name;
        f-hook    = item: f item.name item.value;
      in list-to-case shVar f-pattern f-hook list;
    list-to-case = shVar: f-pattern: f-hook: list:
      let 
        make-case = item: ''
          ${f-pattern item})
            ${ f-hook item }
            ;;
          '';
      in ''
        case ${shVar} in
          ${ concatMapStrings make-case list }
        esac
        '';
    attrs-resources = ENVTH_RESOURCES.resources;
    resource-names = attrNames attrs-resources;
    attrs-resources-twopaths =
      mapAttrs (n: v: "${v.store} ${v.local}") attrs-resources;
  in {
    desc = ''Query various aspects of the "${name}" environment.'';
    commands.resource = {
      desc = "Show resources associated with environment.";
      commands.list.hook = arg-def.resource.completion.hook;
      commands.show.args = [arg-def.resource];
      commands.show.hook = attrs-to-case "$1" (_: v:"echo ${v.store} ${v.local}") attrs-resources;
      };

    commands.varsets = recursiveUpdate {
      desc = "Show environment variable sets defined in env-varsets";
      commands.list = {
        desc = "Show available varsets.";
        hook = ''echo ${show-attrs-with-sep " " (n: _: n) varsets}'';
        }; } (if varsets == {} then {} else {
      commands.show = {
        desc = "Show the names and values assignments of a varset.";
        args = [arg-def.varset];
        hook = ''declare varset=$1'';
        commands.vars.hook = attrs-to-case "$varset" (_: v:"echo ${toString (attrNames v)}") varsets;
        commands.value.args = [ "var"  ];
        commands.value.hook = 
          let showVal = _: varset: attrs-to-case "$1" (_: v: ''echo ${toString v}'') varset;
          in attrs-to-case "$varset" showVal varsets;        
        };
      });
    commands.envvars = {
      desc = ''Show the environment variables set in the "${name}" mkEnvironment definition'';
      commands.list.desc = "Show the variable names.";
      commands.list.hook = "echo ${toString (attrNames attrs-pre)}";
      commands.show.args = [ {name="envvar"; choice = attrNames attrs-pre; } ];
      commands.show.hook = attrs-to-case "$1" (_: v: ''echo ${toString v}'') attrs-pre;
    };
    commands.lib = {
      desc = ''Show functions exported by the "${name}" environment.'';
      hook = ''
        declare sep=" "
        echo "${concatStringsSep "\${sep}" ([fname] ++ (attrNames envlib) )}"
        '';
    };
    commands.imports = {
      desc = "Show environments imported by this environment, recursively.";
      opts = { declared.desc = "Only show environments declared by the environment definition.";
               declared.set = "declared"; };
      hook = ''
        if [[ -n $declared ]]; then
          echo "${toString (map (i: i.name) envs-imported-declared)}"
        else
          echo "${toString (map (i: i.name) envs-imported)}"
        fi
        '';
    };
    commands.envs = {
      desc = ''Show environments added through attribute "env-addEnv".'';
      commands.list.desc = "List added environments.";
      commands.list.hook = ''
        echo ${show-envs-added}
        '';
      commands.show.desc = "Show the nix store location of added environment.";
      commands.show.args = [ arg-def.env ];
      commands.show.hook = 
        list-to-case "$1" (env: env.name) (env: ''echo ${env.outPath}'') envs-added;
    };

    commands.project = 
      let project-cases = f: attrs-to-case "$1" (_: f) projects;
      in recursiveUpdate {
        commands.list.hook = ''echo ${concatStringsSep " " project_names}''; } (if projects == {} then {} else {
        commands.show.args = [ {name="project"; choice=attrNames projects;}];
        commands.show.hook = project-cases ({path,env}:"echo ${path}");
        });
  };
}
