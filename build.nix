{ writeScript, writeScriptBin, nix }:
rec {
  make-builder = self: attrs@{ name, ENVTH_DRV ? "", ... }:
    { builder = writeScript "${name}-builder" ''
        source $stdenv/setup
        mkdir -p $out/bin
        cp $this_enter_env $out/bin/enter-${name}
        '';
      this_enter_env = writeScript "enter-${name}" ''
        export ENVTH_ENTRY=bin
        ${nix}/bin/nix-shell ${ENVTH_DRV} "$@"
        '';
      };

  add-drv-path = drv: _: _: { ENVTH_DRV = drv.drvPath; };

}
