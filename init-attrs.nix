{lib, env-th}:
with lib; with env-th.lib;
rec {

  # ???
  accum-attrs-by = fs: attr: foldl'
    (acc: f: recursiveUpdate acc (f acc)) attr fs;

  save-attrs-as = name: self: super@{passthru ? {}, ... }:
    /* { passthru = filterAttrs (n: v: n == "passthru" ) super; }; */
  let f = _: { "${name}" = super; };
    in { passthru = accum-attrs-by [f] passthru; };
      /* __toString = x:""; */

  set-default-build-dir = self: super@{definition, ...}:
    diffAttrs { ENVTH_BUILDDIR = dirOf (toString definition);} super;


}
