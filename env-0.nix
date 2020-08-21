{nix}:
{
  name = "env-0";
  shellHook = ''
    env-set-PS1
    ENVTH_OUT=''${ENVTH_OUT:=$out}
    '';
  definition = ./env-0.nix;
  lib = {

    # BUILDING The environment
    env-build = ''
      if [[ $ENVTH_ENTRY ~= bin ]]; then
        mkdir -p $ENVTH_BUILDDIR/.env-th
        ENVTH_OUT="$(${nix}/bin/nix-build --quiet $ENVTH_BUILDDIR/$definition \
          -o $ENVTH_BUILDDIR/.env-th/result)"
      fi
      echo $ENVTH_OUT
            '';
    env-cleanup = ''
      unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
            ENVTH_OUT
      '';
    env-entry-path = ''
      if [[ $ENVTH_ENTRY == bin ]]; then
        echo -n "$ENVTH_OUT/bin/enter-$name"
      else
        echo -n "$(env-build)/bin/enter-$name"
      fi
      '';
    env-reload = ''
      local pth=$ENVTH_BUILDDIR
      local enter="$(env-entry-path)"
      local method=$ENVTH_ENTRY
      env-cleanup
      if [[ $method == bin ]]; then
        exec $enter
      else
        exec nix-shell $pth/$definition
      fi
      '';
    env-reload-command = ''
      local pth=$ENVTH_BUILDDIR
      local enter="$(env-entry-path)"
      local method=$ENVTH_ENTRY
      env-cleanup
      if [[ $method == bin ]]; then
        exec $enter --command "$@ ; return"
      else
        exec nix-shell $pth/$definition --command "$@ ; return"
      fi
      '';

    ## Migrating to other hosts
    # Use in conjunction with NIX_SSHOPTS for versitile copies.
    env-deploy = ''
      nix-copy-closure --include-outputs --to $1 $(env-build) $buildInputs
      '';
    env-ssh = ''
      env-deploy "$1" && env-ssh-enter "$(env-entry-path)" "$@"
      '';
    env-ssh-enter = ''
      # Mind the quotes on the called commands.
      # e.g. env-ssh-no-update HOST --command '"echo hi; return"'
      local enter="$1"; shift
      local ssh_cond
      local host="$1"; shift
      echo "#############"
      echo "Will connect to $host"
      echo "With args: $@"
      echo "#############"
      echo ssh $NIX_SSHOPTS "$host" -t "bash -i -- $enter $@"
      ssh $NIX_SSHOPTS "$host" -t "bash -i -- $enter $@"
      ssh_cond=$?
      echo "--- Returned to $(hostname) ---"
      return $ssh_cond
      '';
    env-su = ''
      sudo su --shell $(env-entry-path) $@
      '';

    ## Recreating original source environmet
    env-localize = ''
      echo "%% Making Local Resources %%%%%%%%%%%%%%%%%%%%%%%"
      local arr
      eval "arr=( $ENVTH_RESOURCES )"
      for i in "''${arr[@]}"; do
        env-cp-resource $i
      done
      '';
    env-home-dir = ''
      ENVTH_BUILDDIR=''${ENVTH_BUILDDIR:=$PWD}
      echo $ENVTH_BUILDDIR;
      '';
    env-cp-resource = ''
      local home
      home=$(env-home-dir)
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


    ## OTHER UTILITIES
    env-set-PS1 = let
      pcolor = c: ''\[\033[${c}m\]'';
      in ''
      local c1 c2 c3 cx
      cx=0
      case $# in
      1)
        c1="$1"
        c2="$1"
        c3="$1"
        ;;
      2)
        c1="$1"
        c2="$2"
        c3="$2"
        ;;
      3)
        c1="$1"
        c2="$2"
        c3="$3"
        ;;
      *)
        c1="0;35"
        c2="1;34"
        c3="0;36"
        ;;
      esac
      PS1="\n${pcolor "\${c1}"}[$name]${pcolor "\${c2}"}\u@\h:${pcolor "\${c3}"}\W${pcolor "0"}\$ "
    '';

    env-fst = ''
      echo $1
      '';
  };
}
