{ envth, writeScript, stdenv, makeWrapper, bash, bashInteractive, coreutils }:


rec {
  make-builder = self: super@{ name, ENVTH_DRV ? ""
                             , buildInputs ? [], paths ? []
                             , ... }:
    { builder = writeScript "${name}-builder" ''
        # Save the environment to capture all variables that nix put
        # in the environment.
        ${coreutils}/bin/mkdir -p $out/share
        declare -px > $out/share/${name}-pre.env
        ${coreutils}/bin/env -i ${fix-env} \
          $out/share/${name}-pre.env $out/share/${name}-post.env

        source $stdenv/setup

        # Create output programs.
        mkdir -p $out/bin
        makeWrapper $this_enter_env_sh $out/bin/enter-${name} \
          --set ENVTH_OUT $out
        makeWrapper $this_enter_env_dev $out/bin/enter-${name}-dev \
          --set ENVTH_OUT $out
        # non-interactive is to ensure that the shell hangs up correctly
        # (ran into problems with pdsh and entering the shell)
        makeWrapper $this_enter_env_sh $out/bin/enter-${name}-non-interactive \
          --set ENVTH_OUT $out \
          --set NONINTERACTIVE 1
        '';

      this_enter_env_sh = writeScript "enter-${name}" ''
        #!${bash}/bin/bash
        # enter-${name} [CommandString]
        # enter the environment, optionally running the CommandString

        [[ -n $ENVTH_DEBUG ]] && {
          echo ENVTH_DEBUG=$ENVTH_DEBUG
          echo "##### enter-${name}: $HOSTNAME #######"
          for arg in "$@"; do
            echo " - arg: $arg"
          done; }

        export ENVTH_ENTRY=bin

        # Inherit the build environment, modify to be more like nix-shell env
        source $ENVTH_OUT/share/${name}-post.env
        export NIX_BUILD_TOP=/run/user/$(id -u $USER)
        export TEMP=$NIX_BUILD_TOP
        export TEMPDIR=$NIX_BUILD_TOP
        export TMP=$NIX_BUILD_TOP
        export TMPDIR=$NIX_BUILD_TOP
        export IN_NIX_SHELL=impure

        TMPPATH=$PATH
        source ${stdenv}/setup
        export PATH="$PATH:$TMPPATH"

        # The following is for nix-shell compatability with the --command
        # option. Commands may be given as options, e.g,
        #  - for issuing commands in the environment:
        #     > enter-this-env "echo this; echo that"
        #  - for issuing commands in the environment, then staying in env:
        #     > enter-this-env "echo this; echo that; return"
        # No options is an implicit "return"
        if [[ -z "$@" ]]; then
          export ENVTH_COMMANDLINEHOOK=return
        else
          export ENVTH_COMMANDLINEHOOK="$@"
        fi
        eval-ENVTH_COMMANDLINEHOOK(){
          [[ -n $ENVTH_DEBUG ]] && echo "ENVTH_COMMANDLINEHOOK=$ENVTH_COMMANDLINEHOOK"
          eval "$ENVTH_COMMANDLINEHOOK"
          exit
        }
        export -f eval-ENVTH_COMMANDLINEHOOK

        if [[ -n $NONINTERACTIVE ]]; then
          [[ -n $ENVTH_DEBUG ]] && echo NONINTERRACTIVE
          exec ${bashInteractive}/bin/bash -c "$shellHook
          eval-ENVTH_COMMANDLINEHOOK"
        else
          [[ -n $ENVTH_DEBUG ]] && echo INTERACTIVE
          exec ${bashInteractive}/bin/bash --init-file <(echo "$shellHook
          eval-ENVTH_COMMANDLINEHOOK")
        fi
        '';

      this_enter_env_dev = writeScript "enter-${name}-dev" ''
        #!${bash}/bin/bash
        export ENVTH_ENTRY=bin
        export ENVTH_OUT
        nix-shell ${ENVTH_DRV} "$@"
        '';

      buildInputs = [makeWrapper bash] ++ paths ++ buildInputs;
      };
  fix-env = writeScript "fix-env" ''
          #!${bash}/bin/bash
          # Unset variables in an environment so as not to interfere
          # when re-sourced.
          source $1
          unset PATH PWD TEMP TEMPDIR TMP TMPDIR HOME OLDPWD
          declare -px > $2
          '';

  add-drv-path = drv: self: _: { ENVTH_DRV = drv.drvPath;
                                 /* ENVTH_OUTPATH = self.outPath;  */
                               };

}
