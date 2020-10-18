{ envth, buildEnv, reflex-platform, project-file ? ./reflex-project-default.nix }:
with envth;
let
  checkghc = ''
    # Checks: 1 input; ghc or ghcjs.
    local use="Use: enter-reflex-shell {ghc|gjcjs}"
    [[ $# != 1 ]] && { echo $use ; return; }
    local ghc=$1
    [[ -n ''${ghc/?(ghc|ghcjs)/} ]]  && { echo $use; return; }
    '';
in mkEnvironment rec
{
  name = "reflex-platform";
  definition = ./reflex-platform.nix;
  passthru = {
    reflex = rec {
      inherit reflex-platform;
      project = reflex-platform.project (import project-file); }; };
  envlib =
  {
    /* open-local-frontend = ''
      local uri="file://$(cat FRONTEND_DIR)/index.html"
      echo $uri
      xdg-open $uri
      ''; */
    reflex-enter-shell = ''
      # Enters the reflex shell as per the reflex way, but runs the
      # envth shellHook to initialize the shell as per envth.
      ${checkghc}
      ENVTH_NOCLEANUP=1 env-reload-with-args -A reflex.project.shells.$ghc \
       --command "name=reflex-$ghc; $shellHook return"
      '';
    reflex-open-doc = ''
      local use="Will only work after 'load-reflex-shell {ghc|ghcjs}'"
      local ghc=''${name##*-}
      [[ -n ''${ghc/?(ghc|ghcjs)/} ]]  && { echo $use; return; }
      use="Use: reflex-open-doc <package-name>"
      [[ $# != 1 ]] && { echo $use ; return; }
      local doc=file://$(arg-n 2 $(''${ghc}-pkg field $1 haddock-html))/index.html
      echo $doc
      xdg-open $doc
      '';
    reflex-init-default-project = ''
      echo ${ ./reflex-project-default.nix }
      env-cp-file ${ ./reflex-project-default.nix } reflex-project-default.nix
      '';

    /* This Attempted to merge the reflex shell with the current shell.
    It worked in conjucntion with the passthru attributes to create a local
    link to a buildEnv based on the paths reflex would set up. Never
    was able to get the appropriate attributes though.
    reflex-load-shel = ''
      # Brings the reflex shell into current scope. Use instead
      # of "nix-shell projects.shells.{ghc|ghcjs} .shell.nix"
      ${checkghc}
      # Link shell and add to path as appropriate
      local envhome="$(env-home-dir)"
      case ":$PATH" in
        *:$envhome/reflex-shell/bin:*) : ;;
        *) PATH=$envhome/reflex-shell/bin:$PATH ;;
      esac
      nix-build -A "reflex-platform.shell-env.$ghc" $definition \
        --out-link reflex-shell
      #nix-build -A "reflex-platform.project.shells.$ghc" $definition \
      #  --out-link reflex-shell
      ''; */

  };
}
