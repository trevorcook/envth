{ metafun, lib, flakePath }:
with lib;
let
  build-opts = {
    update-inputs.desc = ''Update the environment's flake.'';
    update-inputs.hook = ''nix flake update --flake "path:$ENVTH_BUILDDIR"'';
  };
 
in 
metafun "envth"  {
      desc = "Utilities for working with envth environments.";
      preOptHook = ''declare __vargsin__=("$@")'';
      commands = {
        new = { 
          desc = ''
            Create a new envth environment.'';
          hook = ''
            nix flake init -t ${flakePath.sourceInfo.outPath}#new
            '';
        };

        enter = {
          desc = ''
            Enter an envth environment.'';
          opts = { inherit (build-opts) update-inputs; };  
          # Most options expect imported env, enter is for associated (or project) envs.
          # args = [ arg-def.added-env ];
          hook = ''
            if [[ -z $ENVTH_BUILDDIR ]]; then
              declare -xg ENVTH_BUILDDIR=$PWD
            fi
            exec nix develop "$@" "$ENVTH_BUILDDIR"#
            '';
        };
        reload = {
          desc = ''Reload current environment. Will either update enviornment definition if entered from nix develop or reenter current shell if binary based.'';
          opts = { inherit (build-opts) update-inputs; };
          hook = ''
            envth enter
            '';
        };

        build = {
          desc = ''Build the environment output--a script that enters an intertactive session based on the nix-shell of an enviornment's definition.
            Note, this will build the most current defintion, which may differ from currently loaded defintion.'';
          # opts = { env = opt-def.env // { arg = arg-def.added-env; }; };
          #   # A = attrs;
          #   # attrs.desc = "Build an attribute within the definition.";
          #   # attrs.set = "attropt";
          #   # attrs.arg = true;
          #   env.desc = "Build the requested environment.";
          #   env.set = "envname";
          #   env.arg = arg-def.envs;
          # };
          hook = ''
            if [[ -n "$ENVTH_BUILDDIR" ]]; then
              mkdir -p "$ENVTH_BUILDDIR/.envth"
              declare envname=''${envname:=$name}
              echo "building... ($ENVTH_BUILDDIR/.envth/build.log)"
              nix build -o "$ENVTH_BUILDDIR/.envth/$envname" \
                $ENVTH_BUILDDIR#$name \
                &> "$ENVTH_BUILDDIR/.envth/build.log"

              # in nix develop, out defaults to PWD/outputs/out  
              ENVTH_OUT="$( readlink $ENVTH_BUILDDIR/.envth/$envname )"
              #   out=$ENVTH_OUT
            fi'';
        };

        entry-path = {
          desc = ''Echo the enter-env-$name location, of current enviornment, building if necessary.'';
          hook = ''
            [[ -e $ENVTH_OUT ]] || envth build &> /dev/null
            # The below acts as "realpath $ENVTH_OUT" but hopefully more portable.
            ( cd -P $(dirname $ENVTH_OUT/bin/enter-env-$name)
              printf '%s\n' "$(pwd -P)/enter-env-$name"
            )
            '';
          };

        # project = {
        #   desc = "Work with environment projects, non-flake environments associated with the current environments.";
        #   commands = {
        #     list.desc = ''Show projects associated with current environment.'';
        #     list.hook = ''envfun-$name project list''; 
        #     show = {
        #       desc = ''The environment nix file location.'';
        #       args = [ arg-def.project ];
        #       hook = ''envfun-$name project show $1'';
        #     };
        #     enter = {
        #       desc = ''Change to specified project's directory and enter project sub-environment.'';
        #       opts = { no-cd.desc = "Stay in current directory"; 
        #                no-cd.set = "nocd"; };
        #       args = [ arg-def.project ];
        #       hook = '' 
        #         ( declare -gx ENVTH_PROJECTDIR=$( dirname $(envth project show $1) )
        #           [[ -z $nocd ]] && cd $ENVTH_PROJECTDIR
        #           envth enter $1
        #         )
        #         '';
        #       };
        #     };
        #   };

        ssh = {
          desc = ''SSH to the current environment on a foreign host. Allows ssh command string following <to>. Use in conjunction with NIX_SSHOPTS to supply extra ssh options. Use with ENVTH_SSH_EXPORTS to export selected enviornment variables to foreign host.'';
          opts = rec {
            no-deploy.desc = "Do not (re)copy environment to host.";
            no-deploy.set = "nodeploy";
            x = no-deploy // { desc = "Same as --no-deploy"; };
            env-path.desc = ''Use the supplied path instead of the current envth entry-path'';
            env-path.set = "enter";
            env-path.arg = true;
            b.desc = "Run the supplied command in the background, hangup.";
            b.set = "background";
            background = b // {desc = b.desc + " Same as -b"; };
            logfile.desc = "Log output of command to file. Used with --background.";
            logfile.set = "logfile";
            logfile.arg = true;
            append-logs.desc = "Do not erase previous log.";
            append-logs.set = "append_logs";
          };
          args = [ "to" ];
          hook = ''
            declare host="$1"; shift
            { [[ $nodeploy == true ]] || envth deploy "$host" ; } && \
            {
              declare ssh_cond
              declare cmd="$(envth misc cmd-wrap "$(envth misc export-cmd "$@")")"
              if [[ -z $background ]]; then
                declare enter=''${enter:=$(envth entry-path)};
                declare enter_cmd="$enter $cmd"
                declare TOPT="-t"
              else
                declare enter=''${enter:=$(envth entry-path)-non-interactive};
                logfile=''${logfile:=envth_ssh.log}
                if [[ -z $append_logs ]]; then
                  declare enter_cmd="nohup $enter $cmd > $logfile 2> $logfile.err < /dev/null &"
                else
                  declare enter_cmd="nohup $enter $cmd >> $logfile 2>> $logfile.err < /dev/null &"
                fi
                declare TOPT="-T"
              fi

              echo "##########################"
              echo "Will connect to $host"
              [[ -n "$*" ]] && {
                echo "Command arguments:"
                for i in "$cmd"; do
                  echo " - arg: $i"
                done ; }
              echo "~~~~~~~~~~~~~"
              echo ssh $TOPT $NIX_SSHOPTS "$host" "$enter_cmd"
              echo "##########################"
              ssh $TOPT $NIX_SSHOPTS "$host" "$enter_cmd"
              ssh_cond=$?
              echo "--- Returned to $(hostname) ---"
              return $ssh_cond
            }
            '';
        };

        deploy = {
          desc = ''Migration to other hosts. Use in conjunction with NIX_SSHOPTS.'';
          args = ["to"];
          hook = ''
            envth build
            nix-copy-closure --to $1 $ENVTH_OUT
            '';
        };


        # install = {
        #   desc = "Install current environment via nix profile.";
        #   opts.bashrc.desc = "Add call to environment in current user's .bashrc.";
        #   opts.bashrc.set = "bashrc";
        #   hook =
        #     let
        #       guarded-exec = ''
        #         [[ -z \$PS1 ]] || [[ -n \$ENVTH_ENTRY ]] || exec enter-env-$name \"source ~/.bashrc ; envth misc set-PS1; return\" \n'';
        #     in ''
        #     if [[ $ENVTH_ENTRY != bin ]]; then
        #       envth build
        #     fi
        #     nix profile remove $name &> /dev/null
        #     nix profile install $ENVTH_OUT
            
        #     if [[ $bashrc == true ]]; then
        #     sed -i "1s:^:${guarded-exec}:" ~/.bashrc
        #     #echo "install, $bashrc"
        #     fi
        #     '';
        # };
        # home-dir = {
        #   desc = "Show the base directory for current environment.";
        #   hook = ''
        #   if [[ -n $NIX_STORE && -z ''${ENVTH_BUILDDIR##$NIX_STORE*} ]]; then
        #     #ENVTH_BUILDDIR=$PWD
        #     :
        #   else
        #     ENVTH_BUILDDIR=''${ENVTH_BUILDDIR_:=$PWD}
        #   fi
        #   echo $ENVTH_BUILDDIR;
        #   '';
        # };

        # cleanup = {
        #   desc = "Remove environment variables from environment";
        #   hook = ''
        #     [[ -n $ENVTH_NOCLEANUP ]] && { return;}
        #     declare -gx ENVTH_BUILDDIR_="$ENVTH_BUILDDIR"
        #     # unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
        #     #       ENVTH_OUT 
        #     unset ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
        #           ENVTH_OUT

        #     #Dont remove ENVTH_TEMP, that will be reused in reload.'';
        #   };


        # repl = {
        #   desc = "A `nix repl` session with the current definition loaded.";
        #   opts.make-repl-file.desc = "Make a temporary repl file to pre-load environment in repl.";
        #   opts.make-repl-file.exit = true;
        #   opts.make-repl-file.hook = ''
        #     cat >$ENVTH_TEMP/repl.nix <<EOF
        #     let
        #       flake = builtins.getFlake (toString $ENVTH_BUILDDIR/.);
        #       env = flake.outputs.devShells.\''${builtins.currentSystem}.$name;
        #       passthru = { inherit flake; } // env.passthru;
        #     in
        #       env // { inherit passthru; }
        #     EOF
        #     '';

        #   hook = ''
        #     # Two ways to call the repl below. I want one that doesn't 
        #     # recopy the flake into the store cause that was eating up memory.
        #     # This works and adds flake to the passthru
        #     # [[ ! -e $ENVTH_TEMP/repl.nix ]] && envth repl --make-repl-file
        #     # nix repl --impure --file $ENVTH_TEMP/repl.nix
        #     # This works too, and doesn't require the temp file
        #     nix repl --impure ''${ENVTH_BUILDDIR}#''${name}
        #   '';
        # };

        # resource = {
        #   desc = ''Show environment resources.'';
        #   hook = ''
        #     for n in $name $(envfun-$name imports); do
        #       if [[ $n != env0 ]]; then

        #     cat <<EOF
        #     $n ~~~~~~~~~~~~~~~~~~~~~~~~
        #     $(envfun-$n resource list)
        #     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        #     EOF

        #       fi
        #     done
        #     '';
        # };
        # imports = {
        #   desc = ''Show closure of all imported environments.'';
        #   opts.declared.desc = ''Only show those imports declared by environment.'';
        #   opts.declared.set = "declared";
        #   opts.tree.desc = ''Graphical representation of recursive imports. Ignores env0, which is imorted by each environment.'';
        #   opts.tree.set = "tree";
        #   hook = ''
        #     declare imports=$(envfun-$name imports)
        #     if [[ -n $tree ]]; then
        #       for env in $(envfun-$name imports --declared); do
        #         echo $env
        #         # indent the returned imports
        #         paste -d'  ' - - <(name=$env envth imports --tree) < /dev/null
        #       done
        #     else
        #       envfun-$name imports ''${declared:+--declared}
        #     fi
        #   '';
        # };

        # localize = {
        #   desc = ''Copy resources from nix store. Expects zero or more resource names as arguments. Zero arguments implies all.'';
        #   preOptHook = ''
        #     declare -f localize_env__
        #     __localize_env__(){
        #       declare env="$1"
        #       shift
        #       if [[ $# -ne 0 ]]; then
        #          rsrcs=( "$@" )
        #       else
        #          rsrcs=( $(envfun-$env resource list) )
        #       fi
        #       for rsrc in "''${rsrcs[@]}"; do
        #         declare store_and_local="$(envfun-$env resource show "$rsrc")"
        #         if [[ -n $store_and_local ]]; then
        #           envth copy-store $dryrun --to "$copyto" $store_and_local
        #         else
        #           echo "Environment '$env' has no resource '$rsrc' to localize."
        #         fi
        #       done
        #     }
        #   '';
        #   opts = with opt-def; { inherit dryrun to;
        #     import-dir.desc = "Directory prefix for imported resources.";
        #     import-dir.set = "importdir";
        #     import-dir.arg = "dir"; 
        #     imports.desc = "Also localize imports to 'envs' or the value of --import-dir ";
        #     imports.set = "localizeImports";
        #     };
        #   hook = ''
        #     dryrun="''${dryrun:+--dryrun}"
        #     copyto="''${copyto:=.}"
        #     __localize_env__ $name "$@"
        #     if [[ -n $localizeImports ]] || [[ -n $importdir ]]; then
        #       copyto="''${importdir:=envs}"
        #       for env in $(envfun-$name imports); do
        #         __localize_env__ $env "$@"
        #       done
        #     fi
        #     '';
        # };

        # copy-store = {
        #   desc = ''Copy from nix store, creating an individual file or whole directory as appropriate. Copies will check for differences in source and destination file (via md5sum) and back-up destination if different. After copy, write mode is added.'';
        #   opts = with opt-def; { inherit to explicit dryrun; };
        #   preOptHook = ''
        #     arg-n(){
        #       declare n=$1
        #       if [[ $# -le $n ]] ; then
        #         echo 'arg-n: index out of bounds' > /dev/stderr
        #         return;
        #       fi
        #       for i in $(seq $n); do shift; done
        #       echo $1
        #       }
        #     '';
        #   args = ["store-location" "dest"];
        #   hook = ''
        #     # Do the copy
        #     if [[ $explicit == true ]]; then
        #       [[ $dryrun != true ]] && mkdir -p $(dirname $2)
        #       if [[ -e $2 ]] && [[ $(arg-n 1 $(md5sum $1)) == $(arg-n 1 $(md5sum $2)) ]]; then
        #         echo "No Create : $2"
        #       else
        #         echo "Creating  : $2"
        #         if [[ $dryrun != true ]]; then
        #           cp --backup=numbered "$1" "$2"
        #           chmod +w $2
        #         fi
        #       fi
        #     # Set destination directory and expand directories to
        #     # multiple copies.
        #     else
        #       declare copyto=''${copyto:=$(envth home-dir)}
        #       declare dryrun="''${dryrun:+--dryrun}"
        #       if [[ -d $1 ]] ; then
        #         for i in $(find $1 -type f -printf "%P\n"); do
        #           #echo envth copy-store $dryrun --explicit $1/$i $copyto/$2/$i
        #           envth copy-store $dryrun --explicit $1/$i $copyto/$2/$i
        #         done
        #       elif [[ -e $1 ]] ; then
        #         #echo envth copy-store $dryrun --explicit "$1" "$copyto/$2"
        #         envth copy-store $dryrun --explicit "$1" "$copyto/$2"
        #       fi
        #     fi
        #     '';
        #   };


        # envvars = {
        #   desc = ''Show environment variables set by mkEnvironment definition.'';
        #   # opts = with opt-def; {inherit current changed names-only; };
        #   hook = ''
        #     declare allvars
        #     if [[ -n $namesonly ]]; then
        #       for n in $(envfun-''${name} imports) $name; do
        #         allvars+="$(envfun-$n vars) "
        #       done
        #       echo $allvars
        #       echo 
        #       echo $allvars | tr ' ' '\n' | sort -u
        #     else
        #       for n in $(envfun-''${name} imports) $name; do
        #         echo $n ~~~~~~~~~~~~~~~~~~~~~~~~~
        #         envfun-$n envvars list
        #         echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        #       done
        #     fi
        #     '';
        # };
        # varsets = {
        #   desc = ''Manipulate variable sets, 'varsets', defined by the environment and imports.'';
        #   commands.list = {
        #     desc = ''List the names of variable sets associated with each environment.'';
        #     opts = with opt-def; {inherit names-only; };
        #     hook = ''
        #       declare sets
        #       declare -a all=()
        #       for n in $name $(envfun-$name imports); do
        #         sets="$(envfun-$n varsets list)"
        #         all+=( $sets )

        #         if [[ -n $sets ]] && [[ -z $namesonly ]]; then
        #       cat <<EOF
        #       $n ~~~~~~~~~~~~~~~~~~~~~~~~
        #       $sets
        #       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        #       EOF
        #         fi

        #       done
        #       [[ -n $namesonly ]] && echo ''${all[@]}
        #       '';
        #   };
        #   commands.show = {
        #     desc = "Show the value assignments of a particular varset.";
        #     opts = with opt-def; {inherit env;};
        #     args = [{name = "varset";
        #              desc = "The varset attribute.";                  
        #              completion.hook = ''echo $(envth varsets list --names-only)''; }];
        #     hook = "varset=$1";
        #     commands.vars.desc = ''Show the variable names defined in varset.'';
        #     commands.vars.hook = ''
        #       envname=''${envname:=$name}
        #       envfun-$envname varsets show $varset vars
        #       '';
        #     };
        #   commands.set = {
        #     desc = "Set the varset keys to environment variables.";
        #     opts = { inherit (opt-def) env; };
        #     args = [{ name="varset";
        #               desc="The varset attribute.";
        #               completion.hook = ''echo $(envth varsets list --names-only)'';
        #              }];
        #     hook = ''
        #       varset="$1"
        #       envname=''${envname:=$name}
        #       for var in $(envfun-$envname varsets show "$varset" vars); do
        #         declare -xg $var="$(envfun-$envname varsets show "$varset" value $var)"
        #       done
        #       '';
        #   };

        #   };

        # lib = {
        #   desc = ''Show all envlib declarations in order of their import.'';
        #   hook = ''
        #     for n in $(envfun-''${name} imports) $name; do
        #     cat <<EOF
        #     $n ~~~~~~~~~~~~~~~~~~~~~~~~~
        #     $(envfun-$n lib)
        #     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        #     EOF
        #     done
        #     '';
        # };

        # };
        # su = {
        #   desc = "Switch user, inherit environment.";
        #   hook = ''
        #     sudo su --shell $(envth entry-path) $@
        #     '';
        # };
        # sudo = {
        #   desc = "sudo, keeping PATH. (Doesn't use sudo -E because poratability, Ubuntu)";
        #   hook = ''
        #     sudo --preserve-env=PATH "$@"
        #     '';
        # };
        misc = {
          desc = "Miscellaneous routines used by envth.";
          commands.PATH-nub = {
            desc = ''Remove duplicate from PATH.'';
            hook = ''
              PATH=$(echo -n $PATH | awk -v RS=: '!($0 in a) {a[$0]; printf("%s%s", length(a) > 1 ? ":" : "", $0)}')
              '';
            };
          commands.PATH-stores = {
            desc = "Show the portion of PATH from /nix/store.";
            hook = ''
            echo $PATH | tr ":" "\n" | grep /nix/store | tr "\n" " "
            '';
            };
          commands.set-PS1 = {
            desc = "Set the enviornment prompt.";
            hook = let pcolor = c: ''\[\033[${c}m\]''; in ''
              declare c1 c2 c3 cx
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
          commands.cmd-wrap = ''
            # A simple utility for wrapping up commands in "ssh/eval"
            # compatible strings. Didactic.
            [[ -n "$@" ]] && printf '%q ' "$@"
            '';
          commands.export-cmd = {
            desc = ''Prepare a command for export to other hosts by prepending "declare" statements from ENVTH_SSH_EXPORTS'';
            hook =  ''
              declare -a args=()
              declare val
              if [[ -n $ENVTH_SSH_EXPORTS ]]; then
                for i in $ENVTH_SSH_EXPORTS ENVTH_SSH_EXPORTS; do
                # The enter-env script runs the declarations in a function.
                # declare -p will not append a "g" option. Hence the following
                # workaround.
                #  args+=( "$(declare -p $i)
                #" )
                  val="$(declare -p $i)"
                  val="''${val/declare -? $i=/}"
                  args+=( "declare -xg $i=$val
                " )
                done
              fi
              if [[ -z "$@" ]]; then
                args+=( return )
              else
                args+=( "$@" )
              fi
              echo "''${args[@]}"
              '';
            };


        };
        

      };
    }