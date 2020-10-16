{ env-th, lib, callPackage, definition ? ./env-0.nix }: with lib;
with env-th.lib.make-environment;
let defin = definition;
this = mkEnvironmentWith env-0-extensions rec {
  name = "env-0";
  definition = ./env-0.nix;
  shellHook = ''
    [[ $ENVTH_ENTRY == bin ]] && ENVTH_BUILDDIR=.
    env-set-PS1
    env-PATH-nub
    ENVTH_OUT=''${ENVTH_OUT:=$out}
    '';
  /* ENVTH_ENV0 = this; */
  passthru = rec {
    attrs-pre = {
      inherit name definition;
      ENVTH_BUILDDIR = "";
      ENVTH_RESOURCES = "";
      ENVTH_ENTRY = "";
      ENVTH_DRV = "";
      ENVTH_OUT = "";
      ENVTH_CALLER = "";
      ENVTH_NOCLEANUP = ""; };
    };
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
            ENVTH_OUT ENVTH_CALLER
      '';
    env-entry-path = ''
      # Echo the enter-$name location, building if necessary.
      [[ -e $ENVTH_OUT ]] || env-build &> /dev/null
      echo -n "$ENVTH_OUT/bin/enter-$name"
      '';
    env-reload = ''
      # Reload env, passing inputs as commands to be run upon entry.
      cmds="$@" ; [[ -z $cmds ]] && cmds=return ; cmds="$cmds ; return"
      env-reload-with-args --command "$cmds"
      '';
    env-reload-with-args = ''
      # env-reload without the implicit "--comand $@ arg"
      env-build
      local pth="$(env-home-dir)"
      local enter="$(env-entry-path)"
      local method=$ENVTH_ENTRY
      local caller=$ENVTH_CALLER
      [[ -n ENVTH_NOCLEANUP ]] && env-cleanup
      if [[ $method == bin ]]; then
        exec $enter "$@"
      elif [[ $caller == none ]]; then
        exec nix-shell "$@" $pth/$definition
      else
        exec nix-shell --argstr definition $pth/$definition "$@" $caller
      fi
      '';

    env-repl = ''
      local pth="$(env-home-dir)"
      local method=$ENVTH_ENTRY
      local caller=$ENVTH_CALLER
      local pthdef
      if [[ $method == bin ]]; then
        pthdef="$definition_NIXSTORE"
      else
        pthdef="$pth/$definition"
      fi
      if [[ $caller == none ]]; then
          nix repl $pthdef
      else
        nix repl --argstr definition $pthdef $caller
      fi
      '';

    env-reload-here = ''
      # Re-enter the environment in current directory using the
      # file pointed to by `definition`.
      ENVTH_BUILDDIR="."
      unset ENVTH_ENTRY
      env-reload "$@"
    '';
    env-deploy = ''
      ## Migrating to other hosts
      # Use in conjunction with NIX_SSHOPTS for versitile copies.
      env-build
      nix-copy-closure --to $1 $ENVTH_OUT
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

    env-localize = ''$name-localize "$@"'';
    env-localize-to = ''$name-localize-to "$@"'';

    env-home-dir = ''
      if [[ -n $NIX_STORE && -z ''${ENVTH_BUILDDIR##$NIX_STORE*} ]]; then
        ENVTH_BUILDDIR=$PWD
      else
        ENVTH_BUILDDIR=''${ENVTH_BUILDDIR:=$PWD}
      fi
      echo $ENVTH_BUILDDIR;
      '';
    env-cp-resource = ''env-cp-resource-to "$(env-home-dir)" "$@"'';
    env-cp-resource-to = ''
      local use="Use: env-cp-resource-to <dir> /nix/store/location /relative/loc"
      [[ $# != 3 ]] && { echo $use ; return; }
      local dir="$1"
       if [[ -d $2 ]] ; then
        for i in $(find $2 -type f -printf "%P\n"); do
          env-cp-file $2/$i $dir/$3/$i
        done
      elif [[ -e $2 ]] ; then
        env-cp-file "$2" "$dir/$3"
      fi
      '';
    env-cp-file = ''
      mkdir -p $(dirname $2)
      if [[ -e $2 ]] && [[ $(arg-n 1 $(md5sum $1)) == $(arg-n 1 $(md5sum $2)) ]]; then
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
      echo "# Source for all libs can be found at:
      file://$libs_doc/doc/html/index.html"
      '';

  };
};
in this
