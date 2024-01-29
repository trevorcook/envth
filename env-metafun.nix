{lib,envth}:
with builtins; with lib; with envth.lib.resources;
rec {
  envth-function-def = envth.lib.env0.envlib.definition.envth;
  opts = {
    current.desc="Current values of keys as environment variables.";
    current.set="current";
    changed.desc="The current values of changed variables.";
    changed.set="changed";
    names-only.desc="Only print the names of variables set.";
    names-only.set="namesonly";
    array.desc = "Show the varset as the values of an associative array";
    array.hook = ''declare array=true'';
    to.desc = "Copy to directory";
    to.arg = true;
    to.set = "copyto";
    resource.desc = "A resource";
    resource.set = "resource";
    resource.arg = true;
    explicit.desc = ''Copy exact location only, no expansion of directories or setting of base directory with --to.'';
    explicit.set = "explicit";
    dryrun.desc = "Only say what would be done.";
    dryrun.set = "dryrun";
    env.desc = "Perform operation using named environment.";
    env.set = "envname";
    env.arg.name="env";
    env.arg.completion.hint = "<env>";
    file.desc = "Use file";
    file.set = "fileinput";
    file.arg = true;
    project-opts = {
      inherit (opt-def) dryrun;
      no-dir.desc = "Do not create project subfolder.";
      no-dir.set  = "nodir";
      a.desc = "Localize all projects.";
      a.exit = true;
      };
    };
  pass-flags = concatStringsSep " "
      ["\${current:+--current}"
      "\${changed:+--changed}"
      "\${namesonly:+--names-only}"
      ];

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
    envs-added = attrValues (attrByPath ["passthru" "envs-added"] {} attrs_);

    opt-def = recursiveUpdate opts { 
      env.arg = arg-def.env; 
      project-opts.a.hook = ''
        dryrun=''${dryrun:+--dryrun}
        nodir=''${nodir:+--no-dir}
        for project in $(project list); do
          ${fname} project localize $dryrun $nodir $project
        done
        '';
      }; 
    arg-def = {
      project.desc = "The name of a declared project.";
      project.completion.hint = "<project>";
      project.completion.hook = ''echo ${toString project_names}''; 
      varset.name = "varset";
      varset.choice = attrNames varsets;
      env.name="env"; 
      env.completion.hint = "<env>";
      env.completion.hook = ''echo "${show-envs-added}"'';
    };
    show-attrs-with-sep = sep: f: attrs:
      concatStringsSep sep (mapAttrsToList f attrs);  
    show-attrs-as-assocArray = attrs:
      "( ${show-attrs-with-sep " " show-assocArray-value attrs} )";
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
    attrs-resources-twopaths =
      mapAttrs (n: v: "${v.store} ${v.local}") attrs-resources;
      # Not sure what is going on below, probably playing with different "esc" but this was orig def.
      # let esc = x: x; in
      # mapAttrs (n: v: "${esc v.store} ${esc v.local}") attrs-resources;
  in {
    desc = ''Query and Control aspects of the "${name}" environment.'';
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
    commands.localize = {
      desc = ''Copy "mkSrc" resources from nix store. Expects zero or more resource names as arguments. Zero arguments implies all.'';
      opts = with opt-def; { inherit to dryrun; };
      hook = ''
        dryrun="''${dryrun:+--dryrun}"
        copyto="''${copyto:+--to=$copyto}"
        #declare -p dryrun copyto

        declare -A rsrcs
        ${fname} resource --array=rsrcs
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
        args = if varsets!={} then [arg-def.varset] else [];
        hook = let
          do-set = n: v:
            if isNull v then
              "unset ${n}"
            else ''declare -xg ${n}="${toString v}"'';
        in
          attrs-to-case "$1" (_: show-attrs-with-sep "\n" do-set) varsets;
        };
      commands.list = {
        desc = "Show available varsets.";
        hook = ''echo ${show-attrs-with-sep " " (n: _: n) varsets}'';
      };
      commands.show = {
        desc = "Show the value assignments of a varset.";
        opts = with opt-def; {inherit current changed names-only;};
        args = if varsets!={} then [arg-def.varset] else [];
        hook = ''
          ${attrs-to-case "$1" ( n: s : ''declare -A vars=${ show-attrs-as-assocArray s }'') varsets }
          envth array-vars show ${pass-flags} vars
          '';
      };
    };
    commands.vars = {
      desc = ''Show environment variables set in the "${name}" mkEnvironment definition'';
      opts = with opt-def; {inherit current changed names-only;};
      hook = ''
          declare -A vars=${ show-attrs-as-assocArray attrs-pre }
          envth array-vars show ${pass-flags} vars
          '';
    };
    commands.lib = {
      desc = ''Show functions exported by the "${name}" environment.'';
      hook = ''
        declare sep=" "
        echo "${concatStringsSep "\${sep}" ([fname] ++ (attrNames envlib) )}"
        '';
    };
    commands.imports = {
      desc = "Show environments imported by this environment.";
      hook = ''
        echo "${toString (map (i: i.name) envs-imported)}"
        '';
    };
    commands.env = {
      desc = ''Show environments added through attribute "env-addEnv".'';
      commands.list.desc = "List added environments.";
      commands.list.hook = ''
        echo "${show-envs-added}"
        '';
      commands.show.desc = "Show the nix store location of added environment.";
      commands.show.args = [ arg-def.env ];
      commands.show.hook = 
        list-to-case "$1" (env: env.name) (env: ''echo ${env.outPath}'') envs-added;
    };
    commands.project = 
      let 
        copyProject = {env,path}: 
          let 
            copyItem = n: v: ''
              envth copy-store $dryrun --to $dir ${v.store} ${v.local}
              '';
          in ''
            declare dir="."
            [[ -z $nodir ]] && dir=${env.name} && [[ -z $dryrun ]] && mkdir -p $dir
            ${concatStrings (mapAttrsToList copyItem env.ENVTH_RESOURCES.resources)}
          '';
        project-cases = f: attrs-to-case "$1" (_: f) projects;
      in recursiveUpdate envth-function-def.commands.project {
        commands.list.hook = ''echo ${concatStringsSep " " project_names}'';
        commands.enter.hook = project-cases ({env,path}: ''
          ( declare -gx ENVTH_PROJECTDIR=$( dirname ${ path } )
            cd $ENVTH_PROJECTDIR
            envth enter ${env.name}
          )
          '');
        commands.definition.hook = project-cases ({path,env}:"echo ${path}");
        commands.localize.hook = ''
          dryrun=''${dryrun:+--dryrun}
          nodir=''${nodir:+--no-dir}
          ${project-cases copyProject}
          '';
        
    #   desc = ''Command for working with "projects", environments that depend upon but not (necessarily) colocated with current (nix flake based) enviornment.'';
    #   commands = {
    #     list.desc = ''Show projects associated with current environment.''; 
    #     list.hook = ''echo ${concatStringsSep " " project_names}''; 
    #     enter = {
    #       desc = ''Change to specified project's directory and enter project sub-environment.'';
    #       args = [ arg-def.project ];
    #       hook = project-cases ({env,path}: ''
    #       ( declare -gx ENVTH_PROJECTDIR=$( dirname ${ path } )
    #         cd $ENVTH_PROJECTDIR
    #         envth enter ${env.name}
    #       )
    #       '');
    #     };
    #     definition = {
    #       desc = ''The environment nix file location.'';
    #       args = [ arg-def.project ];
    #       hook = project-cases ({path,env}:"echo ${path}");
    #     };
    #     localize = {
    #       desc = ''Copy project environments to current directory.'';
    #       opts = with opt-def; {
    #         inherit (project-opts) a no-dir;
    #         inherit dryrun;
    #       };
    #       args = [ arg-def.project ];
    #       hook = ''
    #         dryrun=''${dryrun:+--dryrun}
    #         nodir=''${nodir:+--no-dir}
    #         ${project-cases copyProject}
    #         '';
    #     };
    #   };
    };
  };
}
