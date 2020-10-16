{ env-th, stdenv }: env-th.mkEnvironment
{ name = "new-env";
  definition = ./new-env.nix;
  paths = [];

  shellHook = ''
    PATH_IN=$PATH
    source ${stdenv}/setup
    read -p "Enter path for new environment. [ $PWD ] " ENVPATH
    ENVPATH=''${ENVPATH:=$PWD}
    read -p "Enter environment name. [ $(basename $ENVPATH) ] " ENVNAME
    ENVNAME=''${ENVNAME:=$(basename $ENVPATH)}
    read -p "Use minimal definition? [ N ] " ENVMIN
    ENVMIN=''${ENVMIN:=N}

    mkdir -p $ENVPATH
    if [[ $ENVMIN == N ]] || [[ $ENVMIN == n ]]; then
      substitute ${./env-extended-template.txt} $ENVPATH/''${ENVNAME}.nix \
        --subst-var ENVNAME
    else
      substitute ${./env-template.txt} $ENVPATH/''${ENVNAME}.nix \
        --subst-var ENVNAME
    fi
    substitute ${./default-template.txt} $ENVPATH/default.nix \
        --subst-var ENVNAME
    substitute ${./shell-template.txt} $ENVPATH/shell.nix \
        --subst-var ENVNAME

    cd $ENVPATH
    PATH=$PATH_IN
    unset ENVTH_ENTRY
    exec nix-shell
    '';
}
    /* substituteAll ${./template-env.txt} $ENVPATH/''${ENVNAME}.nix \
    #  --subst-var ENVNAME
    substituteAll ${./default-template.txt} $ENVPATH/default.nix \
    #  --subst-var ENVNAME
    if [[ -n $MKREPL || $MKREPL == [Yy] || $MKREPL == [Yy][eE][sS] ]]; then
      substituteAll ${./repl-template.txt} $ENVPATH/repl.nix \
        #--subst-var ENVNAME
      substituteAll ${./shell-repl-template.txt} $ENVPATH/shell.nix \
        #--subst-var ENVNAME
    else
      substituteAll ${./shell-only-template.txt} $ENVPATH/shell.nix \
        #--subst-var ENVNAME
    fi */
