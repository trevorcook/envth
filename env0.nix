{ envth, lib, callPackage}: with lib;
with envth.lib.make-environment;
let
this = mkEnvironmentWith env0-extensions rec {
  name = "env0";
  definition = ./env0.nix;
  shellHook = ''
    [[ $ENVTH_ENTRY == bin ]] && ENVTH_BUILDDIR=.
    env-set-PS1
    env-PATH-nub
    ENVTH_OUT=''${ENVTH_OUT:=$out}
    export ENVTH_TEMP=''${ENVTH_TEMP:=$(mktemp -d "''${TMPDIR:-/tmp}/ENVTH_$name.XXX")}
    trap 'rm -r $ENVTH_TEMP' EXIT
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
      ENVTH_NOCLEANUP = "";
      ENVTH_TEMP = ""; };
    };
  envlib = {

    env-build = ''
      # Build the output. (A script that enters an interactive
      # session with the current environment variables.)
      if [[ $ENVTH_ENTRY != bin ]]; then
        mkdir -p $(env-home-dir)/.envth
        echo "building... ($ENVTH_BUILDDIR/.envth/build.log)"
        nix-build "$@" -o "$ENVTH_BUILDDIR/.envth/result" \
          "$ENVTH_BUILDDIR/$definition" \
          &> "$ENVTH_BUILDDIR/.envth/build.log"
        ENVTH_OUT="$( readlink $ENVTH_BUILDDIR/.envth/result )"
      fi'';
    env-cleanup = ''
      # Cleanup environment variables. Not sure
      # if this is needed. Am sure its poorly implemented.
      [[ -n ENVTH_NOCLEANUP ]] || return
      unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
            ENVTH_OUT ENVTH_CALLER
      #Dont remove ENVTH_TEMP, that will be reused in reload.'';
    env-entry-path = ''
      # Echo the enter-$name location, building if necessary.
      [[ -e $ENVTH_OUT ]] || env-build &> /dev/null
      echo -n "$ENVTH_OUT/bin/enter-$name"
      '';
    env-reload = ''
      # Reload env, passing inputs as commands to be run upon reentry.
      cmds="$@" ; [[ -z $cmds ]] && cmds=return ; cmds="$cmds ; return"
      env-reload-with-args --command "$cmds"
      '';
    env-reload-with-args = ''
      # env-reload without the implicit "--comand $@ arg"
      env-build
      local pth="$(env-home-dir)"
      local enter="$(env-entry-path)"
      local method=$ENVTH_ENTRY
      # This saturates the definition inputs
      local called=$(env-call $pth/$definition)
      env-cleanup
      if [[ $method == bin ]]; then
        exec $enter "$@"
      else
        exec nix-shell "$@" $called
      fi'';
    env-call = ''
      # Make a nix file that calls the input file using the ENVTH_CALLER.
      # Basically, an ad hoc `shell.nix` that calls the definition with
      # callPackage.
      local def=$1
      echo "import $ENVTH_CALLER { definition = $def; }"\
         > $ENVTH_TEMP/env-call-$(basename $def)
      echo $ENVTH_TEMP/env-call-$(basename $def)'';
    env-repl = ''
      local pthdef
      if [[ $ENVTH_ENTRY == bin ]]; then
        pthdef="$definition_NIXSTORE"
      else
        pthdef="$(env-home-dir)/$definition"
      fi
      nix repl $(env-call $pthdef)'';

    env-reload-here = ''
      # Re-enter the environment in current directory using the
      # file pointed to by `definition`.
      ENVTH_BUILDDIR="."
      unset ENVTH_ENTRY
      env-reload "$@"'';
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