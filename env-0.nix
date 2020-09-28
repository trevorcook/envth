{  }:
rec {
  name = "env-0";
  shellHook = ''
    env-set-PS1
    ENVTH_OUT=''${ENVTH_OUT:=$out}
    '';
  passthru.attrs-pre = { inherit name definition;
    ENVTH_BUILDDIR = "";
    ENVTH_RESOURCES = "";
    ENVTH_ENTRY = "";
    ENVTH_DRV = "";
    ENVTH_OUT = "";
    ENVTH_PATHS_IN_STORE = ""; };
  definition = ./env-0.nix;
  lib = {

    # BUILDING The environment
    env-build = ''
      if [[ $ENVTH_ENTRY != bin ]]; then
        mkdir -p $(env-home-dir)/.env-th
        echo "building... ($ENVTH_BUILDDIR/.env-th/build.log)"
        nix-build "$@" -o "$ENVTH_BUILDDIR/.env-th/result" \
          "$ENVTH_BUILDDIR/$definition" \
          &> "$ENVTH_BUILDDIR/.env-th/build.log"
        ENVTH_OUT="$( readlink $ENVTH_BUILDDIR/.env-th/result )"
      fi
      echo $ENVTH_OUT
            '';
    env-cleanup = ''
      unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
            ENVTH_OUT ENVTH_PATHS_IN_STORE
      '';
    env-entry-path = ''
      echo -n "$(env-build)/bin/enter-$name"
      '';
    env-reload = ''
      local pth="$(env-home-dir)"
      local enter="$(env-entry-path)"
      local method=$ENVTH_ENTRY
      env-cleanup
      # Format inputs run in next env and not exit immediately.
      cmds="$@" ; [[ -z $cmds ]] && cmds=return ; cmds="$cmds ; return"
      if [[ $method == bin ]]; then
        exec $enter "$cmds"
      else
        exec nix-shell $pth/$definition --command "$cmds"
      fi
      '';

    ## Migrating to other hosts
    # Use in conjunction with NIX_SSHOPTS for versitile copies.
    env-deploy = ''
      nix-copy-closure --to $1 $(env-build)
      '';
    env-ssh = ''
      env-deploy "$1" && env-ssh-enter "$(env-entry-path)" "$@"
      '';
    env-ssh-enter = ''
      # Mind the quotes on the called commands.
      # e.g. env-ssh-enter HOST '"echo hi; return"'
      local enter="$1"; shift
      local ssh_cond
      local host="$1"; shift
      echo "#############"
      echo "Will connect to $host"
      echo "With args: \"$@\""
      echo "~~~~~~~~~~~~~"
      echo  ssh $NIX_SSHOPTS "$host" -t "bash -i -- $enter \"$@\""
      echo "#############"
      ssh $NIX_SSHOPTS "$host" -t "bash -i -- $enter \"$@\""
      ssh_cond=$?
      echo "--- Returned to $(hostname) ---"
      return $ssh_cond
      '';
    env-su = ''
      sudo su --shell $(env-entry-path) $@
      '';

    env-localize = ''
      ## For recreating original source environmet.
      echo "%% Making Local Resources %%%%%%%%%%%%%%%%%%%%%%%"
      local arr
      eval "arr=( $ENVTH_RESOURCES )"
      for i in "''${arr[@]}"; do
        env-cp-resource $i
      done
      '';
    env-home-dir = ''
      if [[ -n $NIX_STORE && -z ''${ENVTH_BUILDDIR##$NIX_STORE*} ]]; then
        ENVTH_BUILDDIR=$PWD
      else
        ENVTH_BUILDDIR=''${ENVTH_BUILDDIR:=$PWD}
      fi
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

    #Remove duplicates from path
    env-PATH-nub = ''
      PATH=$(echo -n $PATH | awk -v RS=: '!($0 in a) {a[$0]; printf("%s%s", length(a) > 1 ? ":" : "", $0)}')
      '';
    env-PATH-stores = ''
      echo $PATH | tr ":" "\n" | grep /nix/store | tr "\n" " "
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
    arg-n = ''
      if [[ $# < 2 ]]; then
        echo 'arg-n: needs 2 or more arguments' > /dev/stderr
        return;
      fi
      local n=$1
      if [[ $# -le $n ]] ; then
        echo 'arg-n: index out of bounds' > /dev/stderr
        return;
      fi
      for i in $(seq $n); do shift; done
      echo $1
      '';
    env-lib = ''
      local file name
      # Show all libs in order of their import, but point to the
      # Joined directory where all imports are present.
      for l in $import_libs; do
        for i in $(ls $l/doc/html); do
          [[ $i != index.html ]] && file=$i
        done
        name="''${file%.*}"
        cat <<EOF
      $name ~~~~~~~~~~~~~~~~~~~~~~~~~
      $($name-lib)
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      EOF
      done
      echo "# Links to all contained libs can be found at:
      file://$libs_doc/doc/html/index.html"
      '';

  };
}
