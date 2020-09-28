{lib, env0, writeTextFile, symlinkJoin, pandoc, runCommand, tree }:
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
          { inherit name;
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

  mkImportLibs = name: libs: runCommand name { inherit libs; } ''
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

  mkEnvLib = attrs@{name, lib ? {}, ...}:
    let
      attrs' = filterAttrs (n: v: all (x: n != x)
                    ["lib" "passthru" "ENVTH_DRV"])
                    attrs.passthru.attrs-pre;
      out = mkShellLib name (extras // lib);
      extras = {
        "${name}-lib" = ''
          local sep=" "
          echo "${concatStringsSep "\${sep}" (attrNames (extras // lib ))}"
          '';
        "${name}-vars" = ''
          cat << EOF
          VAR = current_value
          ------------------------------------
          ${show-vars (attrs') }
          EOF
          '';
        };
    in out;

  make-vars-string = f: attrs:
    concatStringsSep "\n" (mapAttrsToList f attrs);
  export-vars = make-vars-string (n: v: "export ${n}=${v}");
  show-vars = show-vars-current;
  show-vars-current = make-vars-string (n: v: "${n} = \${"+"${n}}");
  show-vars-default = make-vars-string (n: v: "${n} = ${builtins.toString v}");
  make-env-lib = self: super@{import_libs ? [], name, ...}:
    let
      lib0 = mkEnvLib env0;
      import_libs_out = uniquer ( [lib0] ++ import_libs ++ [lib] );
      lib = mkEnvLib super;
      lib_doc = mkShellLib-doc name lib;
      sourceLib = l: "source ${l}/lib/*\n";
    in {
      inherit lib;
      import_libs = import_libs_out;
      importLibsHook = concatMapStrings sourceLib import_libs_out;
      libs_doc = mkImportLibs name import_libs_out;
      /* libs_doc = symlinkJoin { inherit name;
        paths = [ import_libs_out ];
        }; */
    };

}
