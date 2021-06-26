{ envth, lib, callPackage}: with lib;
with envth.lib.make-environment;
let
  # TODO: This duplicates env-metafun and shoudl be consolidated
  opt-def = {
    current.desc="Current values of keys as environment variables.";
    current.hook="declare current=true";
    changed.desc="The current values of changed variables.";
    changed.hook="declare changed=true";
    names-only.desc="Only print the names of variables set.";
    names-only.hook="declare namesonly=true";
    /* array.desc = "Show the varset as the values of an associative array";
    array.hook = ''declare array=true''; */
    to.desc = "copy to directory";
    to.hook = _:''declare copyto="$1"'';
    resource.desc = "A resource";
    resource.hook = _: ''declare resource="$1"'';
    explicit.desc = ''Copy exact location only, no expansion of directories
                  or setting of base directory with --to.'';
    explicit.hook = "declare explicit=true";
    dryrun.desc = "Only say what would be done.";
    dryrun.hook = "declare dryrun=true;";
    env.desc = "Use named environment instead of current one.";
    env.hook = _: "declare envname=$1";
    file.desc = _:"Use file";
    file.hook = "declare fileinput=$1";
  };
  array-arg =  [{name="array";desc="The name of an associative array";}];
  pass-flags = concatStringsSep " "
    ["\${current:+--current}"
     "\${changed:+--changed}"
     "\${namesonly:+--names-only}"
     ];
  ## end TODO

this = mkEnvironmentWith env0-extensions rec {
  name = "env0";
  definition = ./env0.nix;
  shellHook = ''
    [[ "$ENVTH_ENTRY" == bin ]] && ENVTH_BUILDDIR=$PWD
    envth set-PS1
    envth PATH-nub
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
      ENVTH_TEMP = "";
      ENVTH_SSH_EXPORTS = "";
    };
  };
  envlib = (import ./env0-legacy-lib.nix) // {

    envth = {
      desc = "envth utilities.";
      commands = {


        caller = {
          desc = ''Make a nix file that calls the definition using the
            ENVTH_CALLER and ENVTH_CALLATTRS. This is basically, an ad hoc
            `shell.nix` that calls the definition with callPackage.'';
          opts = with opt-def; {
            file = file // {
              desc = ''Call "file" instead of environment definition.'';};
          };
          hook = ''
            declare fileinput=''${fileinput:=$(envth home-dir)/$definition}
            echo "import $ENVTH_CALLER $ENVTH_CALLATTRS { definition = $fileinput; }" \
               > $ENVTH_TEMP/env-call-$(basename $fileinput)
            echo $ENVTH_TEMP/env-call-$(basename $fileinput)
            '';
          };

        build = {
          desc = ''Build the environment output--a script that enters an
            intertactive session based on the nix-shell of an enviornment's
            definition.'';
          opts = rec {
            A = attrs;
            attrs.desc = "Build an attribute within the definition.";
            attrs.hook = _: "declare attropt=$1";
          };
          hook = ''
            if [[ $ENVTH_ENTRY != bin ]]; then
              mkdir -p $(envth home-dir)/.envth
              # Make the expression for a callPackage to the current definition.
              local called=$(envth caller)
              # Check if building an attribute, outlink becomes attribute name.
              declare result=''${attropt:=result}
              # Do build
              echo "building... ($ENVTH_BUILDDIR/.envth/build.log)"
              nix-build "$@" -o "$ENVTH_BUILDDIR/.envth/$result" \
                "$called" \
                &> "$ENVTH_BUILDDIR/.envth/build.log"
              [[ $result ==  result ]] && \
                ENVTH_OUT="$( readlink $ENVTH_BUILDDIR/.envth/$result )"
            fi'';
        };

        home-dir = {
          desc = "Show the base directory for current environment.";
          hook = ''
          if [[ -n $NIX_STORE && -z ''${ENVTH_BUILDDIR##$NIX_STORE*} ]]; then
            ENVTH_BUILDDIR=$PWD
          else
            ENVTH_BUILDDIR=''${ENVTH_BUILDDIR:=$PWD}
          fi
          echo $ENVTH_BUILDDIR;
          '';
        };

        cleanup = {
          desc = "Remove environment variables from environment";
          hook = ''
            [[ -n ENVTH_NOCLEANUP ]] && { return;}
            unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
                  ENVTH_OUT ENVTH_CALLER
            #Dont remove ENVTH_TEMP, that will be reused in reload.'';
          };

        entry-path = {
          desc = ''Echo the enter-$name location, of current enviornment,
                   building if necessary.'';
          hook = ''
            [[ -e $ENVTH_OUT ]] || envth build &> /dev/null
            echo -n "$ENVTH_OUT/bin/enter-$name"
            '';
          };
        reload = {
          desc = ''Reload environment, passing inputs as commands
                   to be run upon reentry. Will update enviornment
                   definition if entered from nix-shell or reenter
                   current shell if binary based.'';
          opts = {
            args.desc = ''Pass arguments to nix-shell based reloads.'';
            args.hook = _: ''declare args="$1"'';
            lib.desc = ''Reload the latest source without recompiling
                         the whole environment.'';
            lib.hook = ''declare libonly=true;'';
            here.desc = ''Re-enter the environment in current directory
                          using the file pointed to by `definition`.'';
            here.hook = ''unset ENVTH_ENTRY
                          ENVTH_BUILDDIR="$PWD"
                        '';
          };
          hook = ''
            declare flags=''${libonly:+--lib}
            if [[ -z $args ]]; then
              cmds="$@"
              [[ -z $cmds ]] && cmds=return ;
              cmds="$cmds ; return"
              envth reload $flags --args "--command \"$cmds\""
            else
              if [[ $libonly == true ]]; then
                envth build -A envlib-file
                source $(envth home-dir)/.envth/envlib-file
              else
                envth build
              fi
              if [[ $ENVTH_ENTRY == bin ]]; then
                envth cleanup
                exec $(envth entry-path) $args
              else
                envth cleanup
                eval exec nix-shell $args $(envth caller)
              fi
            fi
            '';
        };

        repl = ''
          if [[ $ENVTH_ENTRY == bin ]]; then
            nix repl $(envth caller --file "$definition_NIXSTORE")
          else
            nix repl $(envth caller)
          fi
          '';

        localize = {
          desc = ''Copy resources from nix store. Expects zero
                  or more resource names as arguments. Zero arguments
                  implies all.'';
          opts = with opt-def; { inherit to dryrun env; };
          hook = ''
            declare envname=''${envname:=$name}
            declare flags="''${dryrun:+--dryrun}"

            declare -A rsrcs
            ''${envname}-env resource --array=rsrcs
            if [[ $# == 0 ]]; then
              for resource in ''${!rsrcs[@]}; do
                envth copy-store $flags ''${rsrcs[$resource]}
              done
            else
              for resource in "$@"; do
                envth copy-store $flags ''${rsrcs[$resource]}
              done
            fi
            '';
        };
        copy-store = {
          desc = ''Copy from nix store, creating an individual file or whole
                   directory as appropriate. Copies will check for differences
                   in source and destination file (via md5sum) and back-up
                   destination if different. After copy, write mode is added.
                   '';
          opts = with opt-def; { inherit to explicit dryrun; };
          args = ["store-location" "dest"];
          hook = ''
            # Do the copy
            if [[ $explicit == true ]]; then
              mkdir -p $(dirname $2)
              if [[ -e $2 ]] && [[ $(arg-n 1 $(md5sum $1)) == $(arg-n 1 $(md5sum $2)) ]]; then
                echo "No Create : $2"
              else
                echo "Creating  : $2"
                if [[ $dryrun != true ]]; then
                  cp --backup=numbered "$1" "$2"
                  chmod +w $2
                fi
              fi
            # Set destination directory and expand directories to
            # multiple copies.
            else
              declare copyto=''${copyto:=$(envth home-dir)}
              declare flags="''${dryrun:+--dryrun}"
              if [[ -d $1 ]] ; then
                for i in $(find $`` -type f -printf "%P\n"); do
                  envth copy-store $flags --explicit $1/$i $copyto/$2/$i
                done
              elif [[ -e $1 ]] ; then
                envth copy-store $flags --explicit "$1" "$copyto/$2"
              fi
            fi
            '';
          };

        /* copy-store-file = {
          desc = ''Copy a file from /nix/store, backing up destination if
                   a different file is detected at target. Add write mode.'';
          args = ["store-file" "dest"];
          hook = ''
            mkdir -p $(dirname $2)
            if [[ -e $2 ]] && [[ $(arg-n 1 $(md5sum $1)) == $(arg-n 1 $(md5sum $2)) ]]; then
              echo "No Create : $2"
            else
              echo "Creating  : $2"
              cp --backup=numbered "$1" "$2"
              chmod +w $2
            fi
            '';
          }; */


        array-vars =
          let
            get-arr = name: ''
              declare temp=$(declare -pn $1)
              declare -A ${name}
              eval "''${temp/$1=/${name}=}"
              '';
          in {
          desc = ''Utility for working with sets of environment variables
                   and associative arrays'';
          commands.set = {
            desc = "Set environment variables based on an associative array.";
            args = array-arg;
            hook = let
              do-set = n: v:
                if isNull v then
                  "unset ${n}"
                else "declare -xg ${n}=${toString v}";
            in
              ''
              echo "array-vars pass-flags=${pass-flags}"
              declare val
              ${get-arr "vars"}
              for key in "''${!vars[@]}"; do
                if [[ -n $key ]] ; then
                  declare -xg $key="''${vars[$key]}"
                else
                  unset $key
                fi
              done
              '';
          };
          commands.show = {
          desc = ''Show values of an associative array'';
          opts = with opt-def; {inherit current changed names-only;};
          args = array-arg;
          hook = ''
              echo "array-vars pass-flags=${pass-flags}"
              declare val
              ${get-arr "vars"}
              for key in "''${!vars[@]}"; do
                if [[ -n $current ]] ; then
                  eval val=$(echo \$$(echo $key))
                  echo "$key=$val"
                elif [[ -n $changed ]]; then
                  eval val=$(echo \$$(echo $key))
                  [[ $val != ''${vars[$key]} ]] && echo "$key=$val"
                elif [[ -n $namesonly ]]; then
                  echo "$key"
                else
                  val=''${vars[$key]}
                  echo "$key=$val"
                fi
              done
              '';
          };
        };

        deploy = {
          desc = ''Migration to other hosts.Use in conjunction with
                   NIX_SSHOPTS.'';
          args = ["to"];
          hook = ''
            envth build
            nix-copy-closure --to $1 $ENVTH_OUT
            '';
        };
        ssh = {
          desc = ''SSH to the current environment on a foreign host.
                   Allows ssh command string following <to>.
                   Use in conjunction with NIX_SSHOPTS to supply extra
                   ssh options.
                   Use with ENVTH_SSH_EXPORTS to export selected enviornment
                   variables to foreign host.'';
          opts = {
            no-deploy.desc = "Do not (re)copy environment to host.";
            no-deploy.hook = "declare nodeploy=true";
            env-path.desc = ''Use the supplied path instead of the
              current envth entry-path'';
            env-path.hook = _:"declare enter=$1";
          };
          args = [ "to" ];
          hook = ''
            declare host="$1"; shift
            { [[ $nodeploy == true ]] || envth deploy "$host" ; } && \
            {
              declare enter=''${enter:=$(envth entry-path)};
              declare ssh_cond
              declare cmd="$(envth export-cmd "$@")"

              echo "##########################"
              echo "Will connect to $host"
              [[ -n "$*" ]] && {
                echo "Command arguments:"
                for i in "$@"; do
                  echo " - arg: $i"
                done ; }
              echo "~~~~~~~~~~~~~"
              echo ssh  -t $NIX_SSHOPTS "$host" "$enter $cmd"
              echo "##########################"
              ssh -t $NIX_SSHOPTS "$host" "$enter $cmd"
              ssh_cond=$?
              echo "--- Returned to $(hostname) ---"
              return $ssh_cond
            }
            '';
        };
        export-cmd = {
          desc = ''Prepare a command for export to other hosts by prepending
                 "declare" statements from ENVTH_SSH_EXPORTS'';
          hook =  ''
            declare -a args=()
            for i in $ENVTH_SSH_EXPORTS ENVTH_SSH_EXPORTS; do
              args+=( "$(declare -p $i)
            " )
            done
            if [[ -z "$@" ]]; then
              args+=( return )
            else
              args+=( "$@" )
            fi
            echo "''${args[@]}"
            '';
          };

        PATH-nub = {
          desc = ''Remove duplicate from PATH.'';
          hook = ''
            PATH=$(echo -n $PATH | awk -v RS=: '!($0 in a) {a[$0]; printf("%s%s", length(a) > 1 ? ":" : "", $0)}')
            '';
        };
        PATH-stores = {
          desc = "Show the portion of PATH from /nix/store.";
          hook = ''
          echo $PATH | tr ":" "\n" | grep /nix/store | tr "\n" " "
          '';
        };

        set-PS1 = {
          desc = "Set the enviornment prompt.";
          hook = let pcolor = c: ''\[\033[${c}m\]''; in ''
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
            PS1="\n${pcolor "\${c1}"}[$name]${pcolor "\${c2}"}$USER@\h:${pcolor "\${c3}"}\W${pcolor "0"}\$ "
          '';
        };

        lib = {
          desc = ''Show all libs in order of their import.'';
          hook = ''
            for n in $(''${name}-env imports) $name; do
            cat <<EOF
            $n ~~~~~~~~~~~~~~~~~~~~~~~~~
            $($n-env lib)
            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

            EOF
            done
            '';
        };

      };
    };

    cmd-wrap = ''
      # A simple utility for wrapping up commands in "ssh/eval"
      # compatible strings. Didactic.
      [[ -n "$@" ]] && printf '%q ' "$@"
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

  };
};
in this
