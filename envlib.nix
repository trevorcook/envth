{lib,  writeTextFile, symlinkJoin, pandoc, runCommand, tree }:
with builtins;
with lib;
let # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls)); in
rec {
  mkShellFunctions = attrs :
    let fs = mapAttrsToList mkShellFunction attrs;
    in concatStrings (mapAttrsToList mkShellFunction attrs);
  mkShellFunction = name: value: ''
    ${name}(){
    ${value}
    }

    '';
  mkShellLibDoc = name: lib-file: runCommand "${name}.html" {} ''
    ${pandoc}/bin/pandoc -f markdown -s --metadata pagetitle=${name} \
      <(  cat <( echo '```bash' ) \
      ${lib-file}  \
      <( echo '```' ) ) \
      -o $out
    '';
  mkShellLib = name: lib:
    let lib-file = writeTextFile
          { name = "${name}-shellLib";
            text = mkShellFunctions lib;
          };
    in runCommand name {} ''
    # Make the Shell Function File
    mkdir -p $out/lib
    ln -s ${lib-file} $out/lib/${name}

    # Make a Version of the Shell Functions as HTML
    mkdir -p $out/doc/html
    ln -s ${mkShellLibDoc name lib-file} $out/doc/html/${name}.html
    ${tree}/bin/tree -H "$out/doc/html/" -L 1 --noreport --charset utf-8 \
      $out/doc/html/. > $out/doc/html/index.html
    '';

  mkImportLibs = name: libs: runCommand "${name}-importLibs" { inherit libs; } ''
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

  mkEnvLib = attrs@{name, envlib ? {}, ENVTH_RESOURCES ? "", ...}:
    let
      attrs' = filterAttrs (n: v: all (x: n != x)
                    ["envlib" "passthru" "ENVTH_DRV" "shellHook" "paths"
                    ])
                    attrs.passthru.attrs-pre;
      assoc = name: value: ''[${name}]="${toString value}"'';
      assocArray = s: "( ${concatStringsSep " " (mapAttrsToList assoc s)} )";
      out = mkShellLib name (extras // envlib);
      extras = {
        "${name}-lib" = ''
          local sep=" "
          echo "${concatStringsSep "\${sep}" (attrNames (extras // envlib ))}"
          '';
        "${name}-vars" = ''
          declare -A vars=${assocArray attrs'}
          if [[ $# == 0 ]] || { [[ $# == 1 ]] && [[ "$1" == "--current" ]]; }; then
            for key in "''${!vars[@]}"; do
                echo "$key = $(eval echo \$$(echo $key))"
            done
          elif [[ $# == 1 ]] && [[ $1 == --original ]]; then
            for key in "''${!vars[@]}"; do
              echo "$key = ''${vars[$key]}"
            done
          elif [[ $# == 1 ]] && [[ $1 == --changed ]]; then
            for key in "''${!vars[@]}"; do
              curval="$(eval echo \$$(echo $key))"
              origval="''${vars[$key]}"
              if [[ $curval != $origval ]]; then
                echo "$key = $curval ($origval)"
              fi
            done
          fi
          '';
        "${name}-localize" = ''''${name}-localize-to "$(env-home-dir)" "$@"'';
        "${name}-localize-to" = ''
            ## For recreating original source environment relative to some directory.
            local use="Use: env-localize-to <dir>"
            [[ $# != 1 ]] && { echo $use ; return; }
            local dir="$1"
            mkdir -p $dir
            echo "%% Making Local Resources in $dir %%%%%%%%%%%%%%%%%%%%%%%"
            local arr
            eval "arr=( $ENVTH_RESOURCES )"
            for i in "''${arr[@]}"; do
              env-cp-resource-to "$dir" $i
            done
            '';
        };
    in out;

  make-vars-string = f: attrs:
    concatStringsSep "\n" (mapAttrsToList f attrs);
  export-vars = make-vars-string (n: v: "export ${n}=${v}");
  show-vars = show-vars-current;
  show-vars-current = make-vars-string (n: v: "${n} = \${"+"${n}}");
  show-vars-default = make-vars-string (n: v: "${n} = ${builtins.toString v}");
  make-envlib = self: super@{import_libs ? [], name, ...}:
    let
      import_libs_out = uniquer ( import_libs ++ [envlib] );
      envlib = mkEnvLib super;
      lib_doc = mkShellLib-doc name envlib;
      sourceLib = l: "source ${l}/lib/*\n";
    in {
      inherit envlib;
      import_libs = import_libs_out;
      importLibsHook = concatMapStrings sourceLib import_libs_out;
      libs_doc = mkImportLibs name import_libs_out;
    };

}
