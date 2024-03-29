{ envth, lib,  writeTextFile, symlinkJoin, runCommand,
  writeScriptBin, tree, metafun }:
with builtins;
with lib;
let # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls)); in
rec {

  # make the environment functionality assiciated with the `envlib` attribute.
  make-envlib = self: super@{import_libs ? [], name, env-varsets?null, envlib?{}, ...}:
    let
      # The metafun specification for "envfun-$name".
      envfun-def = envth.lib.envfun.make-metafun-attrs super;
      envlib-w-envfun = envlib // { "envfun-${name}" = envfun-def;};
      # Supplied envlib functions and envfun-$name are compiled to a bash script.
      envlib-script = make-envlib-script (super // { envlib = envlib-w-envfun; });
      import_libs_out = uniquer ( import_libs ++ [envlib-script] );
      sourceLib = l: ''
        source ${l}/lib/*
        '';
    in {
      envlib = envlib-script;
      env-varsets = if isNull env-varsets then
        null
        else {__toString=_:null;} // env-varsets;
      import_libs = import_libs_out;
      importLibsHook = concatMapStrings sourceLib import_libs_out;
      passthru = super.passthru // {  
        envlib.script = envlib-script;
        envlib.definition = envlib-w-envfun;
        };
    } ;

  # make the environment functionality assiciated with the `envcmd` attribute.
  make-envcmd = self: super@{envcmd?{},import_cmds?[],...}:
    let 
      envcmd_in = envcmd;
      import_cmds_in = import_cmds;
      cmdpth = cmd: ''${toString cmd}/bin:'';
      comppth = "/etc/bash_completion.d";
      paths = concatLists (mapAttrsToList mk-scripts envcmd_in);
      mk-scripts = name: def: 
        let 
          cmd = make-cmd-script name def;
          comp = make-comp-script (comp-name name) def;
          ref = make-comp-reference name "${comp}${comppth}/${comp-name name}";
        in [cmd comp ref];

    in if envcmd_in == {} then {} else rec {
    envcmd = symlinkJoin { 
        name = "envcmd-${super.name}"; 
        inherit paths;
        };
    import_cmds = unique ( [envcmd] ++ import_cmds_in );
    importCmdsHook = ''
      PATH=${concatMapStrings cmdpth import_cmds}$PATH
      for cmds in $import_cmds; do
        for ref in $(ls $cmds/ref); do
          source $cmds/ref/$ref
        done 
      done
      '';
    };

  comp-name = name: "_${name}-complete";
  comp-path = "/etc/bash_completion.d/";
  # make a metafun script-bin file.
  make-cmd-script = name: def: writeScriptBin name (metafun.mkCommand name def);
  # make a metafun completion script-bin file.
  make-comp-script = name: def: writeTextFile {
    inherit name; executable = true; 
    destination = "/etc/bash_completion.d/${name}";
    text = metafun.mkCommandCompletion name def; };
  # Make a file that connects a command with it's completion.
  make-comp-reference = cmd: comp_path: let comp_name = comp-name cmd; in
    runCommand "compref-${cmd}" { inherit cmd comp_path;  } ''
      path="''${out}/ref"
      mkdir -p $path
      cat > $path/$cmd <<EOF
      ${comp_name}(){
        source $comp_path "$@"
      }
      export -f ${comp_name}
      complete -F ${comp_name} $cmd
      EOF
      echo chmod +x $path/$cmd
      '';
  
  # Make a script that creates metafun functions out of all the envlib definitions.
  make-envlib-script = attrs@{ name,envlib?{},... }: writeTextFile {
    name = "${name}-envlib";
    text = concatStrings (mapAttrsToList make-sourced-metafun-fcn envlib) ;
    executable = true;
    destination = "/lib/${name}-envlib.sh";
  };

  # Make a shell function by creating a script from its metafun defintion and sourcing.
  # Sourcing reduces the environment size needed for large functions.
  make-sourced-metafun-fcn = name: def: 
    with metafun; let
      cname = comp-name name;
      cmd = make-cmd-script name def;
      comp = make-comp-script cname def;
    in ''
      ${name}(){
        source ${cmd}/bin/${name} "$@"
      }
      ${cname}(){
        source ${comp}/etc/bash_completion.d/${cname} "$@"
      }
      export -f ${name}
      export -f ${cname}
      complete -F ${cname} ${name}
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
