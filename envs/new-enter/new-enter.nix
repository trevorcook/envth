{ env-th,lib, callPackage, definition ? ./new-enter.nix } : with env-th;
let
  nixlib = lib;
  this = mkEnvironment rec
{ name = "new-enter";
  entvar = 1;
  definition =  ./new-enter.nix;
  
  definition_ =  mkSrc ./new-enter.nix;
  shellHook = ''
    show-things ssss
    '';
  buildInputs = [] ;
  lib = {
    show-things = ''
      echo $1
      echo ENVTH_CALLER=$ENVTH_CALLER
      echo out=$out
      #echo this=
      '';
    /* this-reload = ''
      show-things reloading
      exec nix-shell -A passthru.callenv --argstr $definition $ENVTH_CALLER
      ''; */
    this-reload = ''
      local pth="$(env-home-dir)"
      local enter="$(env-entry-path)"
      local method=$ENVTH_ENTRY
      env-cleanup
      # Format inputs run in next env and not exit immediately.
      cmds="$@" ; [[ -z $cmds ]] && cmds=return ; cmds="$cmds ; return"
      if [[ $method == bin ]]; then
        exec $enter "$cmds"
      else
        #exec nix-shell $pth/$definition --command "$cmds"
        nix-shell -A passthru.callenv --argstr definition $definition \
          $ENVTH_CALLER
      fi
      '';

  };
  passthru = rec {
    inherit env-th nixlib this;
    /* caller = env-th.lib.reloader.caller {}; */
    /* callThis = passthru.callEnv definition {}; */
    nixpkgs = env-th.nixpkgs;
    /* callPk = pk: over:
      let
        pk' = if builtins.typeOf pk == "path"
              then import pk else pk;
      in if nixlib.isFunction pk' then callPackage pk' over else pk';
    callEnv = x: over: passthru.callPk x ({ inherit env-th; }//over); */

  };
}; in this
