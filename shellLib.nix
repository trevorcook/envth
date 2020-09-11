{lib, writeScript }:
with builtins;
with lib;
rec {
  mkShellFunctions = attrs :
    let fs = mapAttrsToList mkShellFunction attrs;
    in concatStrings (mapAttrsToList mkShellFunction attrs);
  mkShellFunction = name: value: ''
    ${name}(){
    ${value}
    }
    '';
  mkShellLib = name: lib: writeScript "${name}-lib" (mkShellFunctions lib);
  mkEnvLib = attrs@{name, lib ? {}, ...}:
    let
      attrs' = filterAttrs (n: v: n != "lib") attrs;
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
  make-env-lib = self: super: { lib = mkEnvLib super; };

}
