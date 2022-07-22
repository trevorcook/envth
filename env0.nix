{ envth, lib, callPackage}: with lib;
with envth.lib.make-environment;
let
  arg-def = {
    envs.name="env"; 
    envs.completion.hint = "<env>";
    envs.completion.hook = ''echo $name $(envfun-$name envs list)'';
    };
  # TODO: This duplicates env-metafun and shoudl be consolidated
  opt-def = {
    current.desc="Current values of keys as environment variables.";
    current.set="current";
    changed.desc="The current values of changed variables.";
    changed.set="changed";
    names-only.desc="Only print the names of variables set.";
    names-only.set="namesonly";
    array.desc = "Show the varset as the values of an associative array";
    array.hook = ''declare array=true'';
    to.desc = "copy to directory";
    to.arg = true;
    to.set = "copyto";
    /* to.hook = _:''declare copyto="$1"''; */
    resource.desc = "A resource";
    resource.set = "resource";
    resource.arg = true;
    explicit.desc = ''Copy exact location only, no expansion of directories or setting of base directory with --to.'';
    explicit.set = "explicit";
    dryrun.desc = "Only say what would be done.";
    dryrun.set = "dryrun";
    /* env.desc = "Use named environment instead of current one.";
    env.set = "envname";
    env.arg = true; */



    env.desc = "Use set from named environment.";
    env.set = "envname";
    env.arg.name="env"; #or the option name (if opt argument).
    env.arg.completion.hint = "<arg:env>";
    env.arg.completion.hook = ''
      echo "$name $(envfun-$name imports)"
      '';
    file.desc = "Use file";
    file.set = "fileinput";
    file.arg = true;
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
    # show_vars PRE
    if [[ $out != $ENVTH_OUT ]]; then
      # If binary, ENVTH_OUT will match out.
      # If shell, will not match or be unset.
      ENVTH_ENTRY=nix-shell
      ENVTH_BUILDDIR=''${ENVTH_BUILDDIR_:-$PWD} 
      out=''${ENVTH_OUT:=$ENVTH_BUILDDIR/.envth/$name}
    else
      envth home-dir >> /dev/null
    fi
    envth set-PS1
    envth PATH-nub
    #export ENVTH_TEMP=''${ENVTH_TEMP:=$(mktemp -d "''${TMPDIR:-/tmp}/ENVTH_$name.XXX")}
    ENVTH_TEMP="$(mktemp -d "''${TMPDIR:-/tmp}/ENVTH_$name.XXX")"
    trap 'rm -r $ENVTH_TEMP' EXIT
    # show_vars POST
    '';
  /* ENVTH_ENV0 = this; */
  passthru = rec {
    attrs-pre = {
      inherit name definition;
      ENVTH_BUILDDIR = "";
      ENVTH_BUILDDIR_ = "";
      ENVTH_RESOURCES = "";
      ENVTH_ENTRY = "";
      ENVTH_DRV = "";
      ENVTH_OUT = "";
      # ENVTH_CALLER = "";
      ENVTH_NOCLEANUP = "";
      ENVTH_TEMP = "";
      ENVTH_SSH_EXPORTS = "";
    };
  };
  envlib = {

    # show_vars = ''
    #   echo "-- $@ ------" 
    #   declare -p ENVTH_BUILDDIR ENVTH_BUILDDIR_ out ENVTH_OUT ENVTH_ENTRY PWD
    #   '';

    envth = {
      desc = "envth utilities.";
      commands = {


        /* caller = {
          desc = ''Make a nix file that calls the definition using the ENVTH_CALLER and ENVTH_CALLATTRS. This is basically, an ad hoc `shell.nix` that calls the definition with callPackage.'';
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
          }; */

        enter = {
          desc = ''
            Replace current environment with an in-scope environment.
              Environments can be added to scope with the "env-addEnvs" attribute and will allow entering from the current environment via this command or with "nix develop .#env".
            '';
          args = [ arg-def.envs ];
          hook = ''
            if [[ $ENVTH_ENTRY == nix-shell ]]; then
              ENVTH_OUT=""
              declare -xg ENVTH_BUILDDIR_="$ENVTH_BUILDDIR"
              exec nix develop "$ENVTH_BUILDDIR/"#"$1"
            else
              declare env
              if [[ $1 == $name ]]; then
                env="$ENVTH_OUT"
              else
                env="$(envfun-$name envs show $1)"
              fi
              exec $env/bin/enter-env-$1
            fi
            '';
        };
        reload = {
          desc = ''Reload current environment. Will update enviornment definition if entered from nix-shell or reenter current shell if binary based.'';
          # opts = {
          #   args.desc = ''Pass arguments to nix-shell based reloads.'';
          #   args.set = "args";
          #   args.arg = true;
          #   lib.desc = ''Reload the latest source without recompiling the whole environment.'';
          #   lib.set = "libonly";
          #   here.desc = ''Re-enter the environment in current directory using the file pointed to by `definition`.'';
          #   here.hook = ''unset ENVTH_ENTRY
          #                 ENVTH_BUILDDIR="$PWD"
          #               '';
          # };
          hook = ''
            envth enter "$name"

            # declare flags=''${libonly:+--lib}
            # if [[ -z $args ]]; then
            #   cmds="$@"
            #   [[ -z $cmds ]] && cmds=":" ;
            #   cmds="$cmds ; return"
            #   [[ $ENVTH_ENTRY == bin ]] || cmds="--command \"$cmds\""
            #   envth reload $flags --args "$cmds"
            # else
            #   if [[ $libonly == true ]]; then
            #     envth build -A envlib-file
            #     source $(envth home-dir)/.envth/envlib-file
            #   else
            #     envth build
            #   fi
            #   if [[ $ENVTH_ENTRY == bin ]]; then
            #     declare pth=$(envth entry-path)
            #     envth cleanup
            #     exec $pth $args
            #   else
            #     envth cleanup
            #     ENVTH_OUT=""
            #     declare -gx ENVTH_BUILDDIR_="$ENVTH_BUILDDIR"
            #     exec nix develop "$ENVTH_BUILDDIR"/.#"$name"
            #   fi
            # fi
            '';
        };

        build = {
          desc = ''Build the environment output--a script that enters an intertactive session based on the nix-shell of an enviornment's definition.
            Note, this will build the most current defintion, which may differ from currently loaded defintion.
            '';
          opts = rec {
            # A = attrs;
            # attrs.desc = "Build an attribute within the definition.";
            # attrs.set = "attropt";
            # attrs.arg = true;
            env.desc = "Build the requested environment.";
            env.set = "envopt";
            env.arg = arg-def.envs;
          };
          hook = ''
            if [[ $ENVTH_ENTRY != bin ]]; then
              mkdir -p $(envth home-dir)/.envth
              # # Check if building an attribute, outlink becomes attribute name.
              # declare result=''${attropt:=result}
              # Check which envrionment to build
              declare envopt=''${envopt:=$name}
              # Do build
              echo "building... ($ENVTH_BUILDDIR/.envth/build.log)"
              nix build -o "$ENVTH_BUILDDIR/.envth/$envopt" \
                $ENVTH_BUILDDIR#$name \
                &> "$ENVTH_BUILDDIR/.envth/build.log"
              [[ $result == result ]] && \
                ENVTH_OUT="$( readlink $ENVTH_BUILDDIR/.envth/$envopt )"
                out=$ENVTH_OUT
            fi'';
        };

        install = {
          desc = "Install current environment via nix-env.";
          opts.bashrc.desc = "Add call to environment in current user's .bashrc.";
          opts.bashrc.set = "bashrc";
          hook =
            let
              guarded-exec = ''
                [[ -z \$PS1 ]] || [[ -n \$ENVTH_ENTRY ]] || exec enter-env-$name \"source ~/.bashrc ; envth set-PS1; return\" \n'';
            in ''
            if [[ $ENVTH_ENTRY != bin ]]; then
              envth build
            fi
            nix profile install $ENVTH_OUT
            
            if [[ $bashrc == true ]]; then
            sed -i "1s:^:${guarded-exec}:" ~/.bashrc
            #echo "install, $bashrc"
            fi
            '';
        };
        home-dir = {
          desc = "Show the base directory for current environment.";
          hook = ''
          if [[ -n $NIX_STORE && -z ''${ENVTH_BUILDDIR##$NIX_STORE*} ]]; then
            #ENVTH_BUILDDIR=$PWD
            :
          else
            ENVTH_BUILDDIR=''${ENVTH_BUILDDIR_:=$PWD}
          fi
          echo $ENVTH_BUILDDIR;
          '';
        };

        cleanup = {
          desc = "Remove environment variables from environment";
          hook = ''
            [[ -n $ENVTH_NOCLEANUP ]] && { return;}
            declare -gx ENVTH_BUILDDIR_="$ENVTH_BUILDDIR"
            # unset ENVTH_BUILDDIR ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
            #       ENVTH_OUT 
            unset ENVTH_RESOURCES ENVTH_ENTRY ENVTH_DRV \
                  ENVTH_OUT
            show_vars POST CLEAN

            #Dont remove ENVTH_TEMP, that will be reused in reload.'';
          };

        entry-path = {
          desc = ''Echo the enter-env-$name location, of current enviornment, building if necessary.'';
          hook = ''
            [[ -e $ENVTH_OUT ]] || envth build &> /dev/null
            echo -n "$ENVTH_OUT/bin/enter-env-$name"
            '';
          };

        repl = {
          desc = "A `nix repl` session with the current definition loaded.";
          opts.make-repl-file.desc = "Make a temporary repl file to pre-load environment in repl.";
          opts.make-repl-file.exit = true;
          opts.make-repl-file.hook = ''
            cat >$ENVTH_TEMP/repl.nix <<EOF
            let
              flake = builtins.getFlake (toString $ENVTH_BUILDDIR/.);
              env = flake.outputs.devShells.\''${builtins.currentSystem}.default;
              passthru = { inherit flake; } // env.passthru;
            in
              env // passthru
            EOF
            '';

          hook = ''
            [[ ! -e $ENVTH_TEMP/repl.nix ]] && envth repl --make-repl-file
            nix repl $ENVTH_TEMP/repl.nix
          '';
        };

        resource = {
          desc = ''Show environment resources.'';
          opts = with opt-def; { inherit current changed names-only; };
          hook = ''
            for n in $name $(envfun-$name imports); do
              if [[ $n != env0 ]]; then
          cat <<EOF
          $n ~~~~~~~~~~~~~~~~~~~~~~~~
          $(envfun-$n resource ${pass-flags})
          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

          EOF
              fi
            done
            '';
        };
        localize = {
          desc = ''Copy resources from nix store. Expects zero or more resource names as arguments. Zero arguments implies all.'';
          opts = with opt-def; { inherit dryrun to;
            import-dir.desc = "Directory prefix for imported resources.";
            import-dir.set = "importdir";
            import-dir.arg = "dir"; };
          hook = ''
            dryrun="''${dryrun:+--dryrun}"
            importdir="''${importdir:=envs}"
            copyto="''${copyto:=.}"
            for n in $name $(envfun-$name imports); do
              if [[ $n == $name ]]; then
                envfun-$n localize $dryrun --to "$copyto"
              #elif [[ $n != env0 ]]; then
              else
                envfun-$n localize $dryrun --to "$copyto/$importdir/$n"
              fi
            done
            '';
        };
        copy-store = {
          desc = ''Copy from nix store, creating an individual file or whole directory as appropriate. Copies will check for differences in source and destination file (via md5sum) and back-up destination if different. After copy, write mode is added.
                   '';
          opts = with opt-def; { inherit to explicit dryrun; };
          args = ["store-location" "dest"];
          hook = ''
            # Do the copy
            if [[ $explicit == true ]]; then
              [[ $dryrun != true ]] && mkdir -p $(dirname $2)
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
              declare dryrun="''${dryrun:+--dryrun}"
              if [[ -d $1 ]] ; then
                for i in $(find $1 -type f -printf "%P\n"); do
                  #echo envth copy-store $dryrun --explicit $1/$i $copyto/$2/$i
                  envth copy-store $dryrun --explicit $1/$i $copyto/$2/$i
                done
              elif [[ -e $1 ]] ; then
                #echo envth copy-store $dryrun --explicit "$1" "$copyto/$2"
                envth copy-store $dryrun --explicit "$1" "$copyto/$2"
              fi
            fi
            '';
          };

        array-vars =
          let
            get-arr = name: ''
              declare temp=$(declare -pn $1)
              declare -A ${name}
              eval "''${temp/$1=/${name}=}"
              '';
          in {
          desc = ''Utility for working with sets of environment variables and associative arrays'';
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
              # echo "array-vars pass-flags=${pass-flags}"
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
              # echo "array-vars pass-flags=${pass-flags}"
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

        varsets = {
          desc = ''
            Manipulate variable sets defined by the environment and imports.
            '';
          commands.set = {
            desc = "Set the varset keys to environment variables.";
            preOptHook = ''
              #declare -f nub
              nub(){
                echo $1 | tr ' ' '\n' | sort -u
              }
              #declare -f elem
              elem(){
                if [[ "$(nub "$1 $2")" == "$(nub "$2")" ]]; then
                  echo true
                else
                  echo false
                fi
              }
              '';
              #declare -f testelem
              #testelem(){
              #  echo "elem \"$1\" \"$2\""? $(elem "$1" "$2")
              #}
              #declare -f _setsargs_list
              #_setsargs_list(){
              #  declare envs="$name $(envfun-$name imports)"
              #  declare sets
              #  for env in $envs; do
              #    sets="$sets $(envfun-$env varsets list)"
              #  done
              #  nub "$sets"
              #}
              #declare -p envs
              #declare envswsets
              #for env in $envs; do
              #  sets="$(envfun-$env varsets list)"
              #  [[ -n $sets ]] && envswsets="$envswsets $env"
              #done
              #declare -p envswsets
              #_setsargs_list
              #testelem 1 "1 2"
              #testelem 2 "1 2"
              #testelem 3 "1 2"
              #echo arg=$1

            args = [{ name="varset"; #or the option name (if opt argument).
                      desc="The varset attribute.";
                      completion.hint = "<arg:varset>";
                      completion.hook = ''
                        declare envs="$name $(envfun-$name imports)"
                        declare sets
                        for env in $envs; do
                          sets="$sets $(envfun-$env varsets list)"
                        done
                        echo $sets | tr ' ' '\n' | sort -u
                        '';
                     }];
            opts = { inherit (opt-def) env; };
            hook = ''
              declare envs="$name $(envfun-$name imports)"
              declare envname=''${envname:=}
              for env in $envs; do
                [[ -n $envname ]] && break
                if [[ true == $(elem "$1" "$(envfun-$env varsets list)") ]]; then
                  envname=$env
                  break
                fi
              done
              if [[ -n $envname ]]; then
                envfun-$envname varsets set $1
              fi
              '';
          };
          commands.list = ''
              declare sets
              declare any
              for n in $name $(envfun-$name imports); do
                sets="$(envfun-$n varsets list)"
                if [[ -n $sets ]]; then

            cat <<EOF
            $n ~~~~~~~~~~~~~~~~~~~~~~~~
            $sets
            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

            EOF

               fi
              done
              '';
          /* commands.show = {
            desc = "Show the value assignments of a varset.";
            opts = with opt-def; {inherit current changed names-only env;};
            args = if varsets!={} then [setsarg] else [];
            hook = ''
              ${sets-case
                 ( n: s : ''declare -A vars=${ show-attrs-as-assocArray s }'')
                 varsets }
              envth array-vars show ${pass-flags} vars
              '';
          }; */

        };
  /* commands.varsets = {
    desc = "Manipulate environment variable sets defined in env-varsets";
    commands.set = {
      desc = "Set the varset keys to environment variables.";
      args = if varsets!={} then [setsarg] else [];
      hook = let
        do-set = n: v:
          if isNull v then
            "unset ${n}"
          else ''declare -xg ${n}="${toString v}"'';
      in
        sets-case (_: show-attrs-with-sep do-set "\n") varsets;
      };
    commands.list = {
      desc = "Show available varsets.";
      hook = ''echo ${show-attrs-with-sep (n: _: n) " " varsets}'';
    };
  }; */





        deploy = {
          desc = ''Migration to other hosts.Use in conjunction with NIX_SSHOPTS.'';
          args = ["to"];
          hook = ''
            envth build
            nix-copy-closure --to $1 $ENVTH_OUT
            '';
        };
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
          };
          args = [ "to" ];
          hook = ''
            declare host="$1"; shift
            { [[ $nodeploy == true ]] || envth deploy "$host" ; } && \
            {
              declare ssh_cond
              declare cmd="$(cmd-wrap "$(envth export-cmd "$@")")"
              if [[ -z $background ]]; then
                declare enter=''${enter:=$(envth entry-path)};
                declare enter_cmd="$enter $cmd"
                declare TOPT="-t"
              else
                declare enter=''${enter:=$(envth entry-path)-non-interactive};
                logfile=''${logfile:=envth_ssh.log}
                declare enter_cmd="nohup $enter $cmd > $logfile 2> $logfile.err < /dev/null &"
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
        export-cmd = {
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

        su = {
          desc = "Switch user, inherit environment.";
          hook = ''
            sudo su --shell $(envth entry-path) $@
            '';
        };
        sudo = {
          desc = "sudo, keeping environmnet variables (just uses sudo -E)";
          hook = ''
            sudo -E "$@"
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
            for n in $(envfun-''${name} imports) $name; do
            cat <<EOF
            $n ~~~~~~~~~~~~~~~~~~~~~~~~~
            $(envfun-$n lib)
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
