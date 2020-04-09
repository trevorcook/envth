{lib}:
with lib;
rec {

  # attrDefaults defaults attrset
  # Get subset of defaults not set in attrset
  attrDefaults =  diffAttrs;
  diffAttrs = a: b: removeAttrs a (attrNames b);

  accum-attrs-by = fs: attr: foldl'
    (acc: f: recursiveUpdate acc (f acc)) attr fs;

  save-attrs = self: super@{passthru ? {}, ... }:
    let f = _: { attrs = super; };
    in { passthru = accum-attrs-by [f] passthru; };
      /* __toString = x:""; */

  set-default-build-dir = self: super@{definition, ...}:
    attrDefaults { ENVTH_BUILDDIR = dirOf (toString definition);} super;


}
