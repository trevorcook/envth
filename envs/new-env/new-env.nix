{ env-th, stdenv }: env-th.mkEnvironment
{ name = "new-env";
  definition = ./new-env.nix;
  buildInputs = [];

  shellHook = ''
    PATH_IN=$PATH
    source ${stdenv}/setup
    read -p "Enter path for new environment. [ $PWD ] " ENVPATH
    ENVPATH=''${ENVPATH:=$PWD}
    read -p "Enter environment name. [ $(basename $ENVPATH) ] " ENVNAME
    ENVNAME=''${ENVNAME:=$(basename $ENVPATH)}
    read -p "Make repl? [ N ] " MKREPL

    mkdir -p $ENVPATH
    substitute ${./template-env.txt} $ENVPATH/''${ENVNAME}.nix \
      --subst-var ENVNAME
    substitute ${./default-template.txt} $ENVPATH/default.nix \
      --subst-var ENVNAME
    if [[ -n $MKREPL || $MKREPL == [Yy] || $MKREPL == [Yy][eE][sS] ]]; then
      substitute ${./repl-template.txt} $ENVPATH/repl.nix \
        --subst-var ENVNAME
      substitute ${./shell-repl-template.txt} $ENVPATH/shell.nix \
        --subst-var ENVNAME
    else
      substitute ${./shell-only-template.txt} $ENVPATH/shell.nix \
        --subst-var ENVNAME
    fi

    cd $ENVPATH
    PATH=$PATH_IN
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
