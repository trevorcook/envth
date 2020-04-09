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
  envth-lib =
   { name = "envth";
     lib = {
          env-cleanup = ''
            unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
                  this_enter_env
            '';
          env-reload = ''
            local pth=$ENVTH_BUILDDIR
            local enter=$this_enter_env
            local method=$ENVTH_ENTRY
            env-cleanup
            if [[ $method == bin ]]; then
              exec $enter
            else
              exec nix-shell $pth/$definition
            fi
            '';
          env-build = ''
            mkdir -p $ENVTH_BUILDDIR/.envth
            ${nix}/bin/nix-build $ENVTH_BUILDDIR/$definition \
               2>$ENVTH_BUILDDIR/.envth/build.log
            '';
          env-home-dir = ''
            ENVTH_BUILDDIR=''${ENVTH_BUILDDIR:=$PWD}
            echo $ENVTH_BUILDDIR;
            '';
          env-localize = ''
            echo "%% Making Local Resources %%%%%%%%%%%%%%%%%%%%%%%"
            local arr
            eval "arr=( $ENVTH_RESOURCES )"
            for i in "''${arr[@]}"; do
              env-cp-resource $i
            done
            '';
          env-cp-resource = ''
            local home
            home=$(env-home-dir)
            home=$PWD #for testing
            if [[ -d $1 ]] ; then
              for i in $(find $1 -type f -printf "%P\n"); do
                env-cp-file $1/$i $home/$2/$i
              done
            elif [[ -e $1 ]] ; then
              env-cp-file $1 $home/$2
            fi
            '';
          env-cp-file = ''
            mkdir -p $(dirname $2)
            if [[ -e $2 && $(env-fst $(md5sum $1)) == $(env-fst $(md5sum $2)) ]]; then
              echo "No Create : $2"
            else
              echo "Creating  : $2"
              cp --backup=numbered "$1" "$2"
              chmod +w $2
            fi
            '';
          env-fst = ''
            echo $1
            '';

        };

     ENVTH_BUILDDIR = "";
    };
  make-env-lib = self: super: { lib = mkEnvLib super; };


}
