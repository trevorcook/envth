{ env-th,lib, callPackage } : with env-th;
let
  nixlib = lib;
  this = mkEnvironment rec
{ name = "new-enter";
  entvar = 1;
  definition =  ./new-enter.nix;
  shellHook = ''
    show-things Boogabooga
    '';
  buildInputs = [] ;
  lib = {
    show-things = ''
      echo "~~~~"
      echo $1
      echo ENVTH_CALLER=$ENVTH_CALLER
      # echo out=$out
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
      local caller=$ENVTH_CALLER
      env-cleanup
      # Format inputs run in next env and not exit immediately.
      cmds="$@" ; [[ -z $cmds ]] && cmds=return ; cmds="$cmds ; return"
      if [[ $method == bin ]]; then
        exec $enter "$cmds"
      elif [[ $caller == none ]]; then
        nix-shell $pth/$definition --command "$cmds"
      else
        nix-shell --argstr definition $pth/$definition $caller --command "$cmds"
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
