{ writeScript, writeScriptBin, nix, makeWrapper }:
rec {
  make-builder = self: attrs@{ name, ENVTH_DRV ? "", buildInputs ? [], ... }:
    { builder = writeScript "${name}-builder" ''
        source $stdenv/setup
        mkdir -p $out/bin
        makeWrapper $this_enter_env $out/bin/enter-${name} \
          --set ENVTH_OUT $out
        # wrapProgram $this_enter_env --set ENVTH_OUT $out
        # cp $this_enter_env $out/bin/enter-${name}
        '';
      this_enter_env = writeScript "enter-${name}" ''
        export ENVTH_ENTRY=bin
        export ENVTH_OUT
        ${nix}/bin/nix-shell ${ENVTH_DRV} "$@"
        '';
       buildInputs = [makeWrapper]++buildInputs;
      };

  add-drv-path = drv: self: _: { ENVTH_DRV = drv.drvPath;
                                 /* ENVTH_OUTPATH = self.outPath;  */
                               };

}
