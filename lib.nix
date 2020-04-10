{lib, writeScript, nix}:
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
          VAR = current_value (declared_value)
          ------------------------------------
          ${show-vars (attrs') }
          EOF
          '';
        };
    in out;

  show-vars = attrs:
    let
      show = n: v: "${n} = \$"+"${n}";
    in
      concatStringsSep "\n" (mapAttrsToList show attrs);
  show-vars-current = varlist:
    let
      show = n: "${n} = \$"+"${n}\n";
    in
      concatMapStrings show varlist;
  show-vars-default = attrs:
    let
      show = n: v: "${n} = ${v}";
    in
      concatStringsSep "\n" (mapAttrsToList show attrs);
  make-env-lib = self: super: { lib = mkEnvLib super; };


}
