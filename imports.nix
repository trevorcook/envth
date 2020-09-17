{callPackage, lib, env-th}: with builtins; with lib;
with env-th.lib;
let
  # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls));
in
rec
  {
    # Add imports overlay
    add-imports = self: {imports ? [],...}@attrs:
      let merged-attrs = foldr merge-import-env attrs imports;
      in post-process-merged-attrs merged-attrs;

    # Merge an imported env into the current attribute set.
    merge-import-env = env_: attrs:
      let
        env = callEnv env-th env_;
        env-attrs = env.passthru.attrs-post;
        upd-attrs = preprocess-import-attrs env-attrs;
        split-env = split-import-attrs upd-attrs;
        merged-specials = merge-special-attrs attrs split-env.specials;
        attrs-out = wDbg (split-env.non-specials // merged-specials) ;
        wDbg = attrs:
          let
            path = ["passthru" "import-data" ];
            old = attrByPath path null attrs;
            new = { inherit env attrs env-attrs upd-attrs split-env
                            merged-specials env_ attrs-out;
                    importing-name = env-attrs.name;
                    import-data = old; };
          in recursiveUpdate attrs (setAttrByPath path new);
      in attrs-out;

    split-import-attrs = attrs:
      let specials = intersectAttrs special-attr.defaults attrs;
      in { inherit specials; non-specials = diffAttrs attrs specials; };

    merge-special-attrs = attrs: special:
      let
        do-merge = {name, value}: (special-attr name).merge-import-value value;
      in foldr do-merge attrs (mapAttrsToList nameValuePair special);

    # Special attributes. Centralized place to keep the behavior of all
    # the attributes I need to keep track of.
    special-attr = {
      __functor = self: name:
        let err =  throw ''special-attr "${name}" not found.'';
        in attrByPath [name] err self.definition;
      definition =
        let
          catlist = name: { merge-import-value = cat-with-default name;
                            default = [];};
          keeplist   = { merge-import-value = ignore; default = [];};
          keepstring = { merge-import-value = ignore; default = "";};
          keepattr   = { merge-import-value = ignore; default = {};};
          ignore = _: attrs: attrs;
          cat-with-default = name: value: attrs:
            let
              orig-value = attrByPath [name] (special-attr name).default attrs;
              new-value = uniquer (orig-value ++ value);
            in attrs // setAttrByPath [name] new-value;
        in {
          buildInputs = catlist "buildInputs";
          addEnvs = keeplist;
          name = keepstring;
          definition = keepstring;
          lib = keepattr;
          import_libs = catlist "import_libs";
          shellHook = keepstring;
          imports = catlist "imports";
          passthru = keepattr;
          envs = keepattr;
        };
      defaults = mapAttrs (_: v: v.default) special-attr.definition;
    };

    # After loading the attributes to merge, do this.
    preprocess-import-attrs = { lib ? [], import_libs ? [], ...}@attrs:
      let
        new-import_libs = import_libs ++ toList lib;
        new-attrs =
          if new-import_libs != [] then
            { import_libs = new-import_libs;}
          else {};
      in attrs // new-attrs;

    # After merging all imports with current attribute set, do this.
    post-process-merged-attrs = {import_libs ? [],...}@attrs:
      let
        f = l: "source ${l}\n";
        new-attrs =
          if import_libs != [] then
            { importLibsHook = concatMapStrings f import_libs ; }
          else
            {};
      in attrs // new-attrs;

  }
