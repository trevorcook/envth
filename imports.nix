{callPackage, lib, env-th, env0}: with builtins; with lib;
with env-th.lib;
let
  # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls));
in
rec
  {
    # Add imports overlay
    add-imports = self: {imports ? [env0],...}@attrs:
      let merged-attrs = foldr merge-import-env attrs imports;
      in merged-attrs;

    # Merge an imported env into the current attribute set.
    merge-import-env = env_: attrs:
      let
        env = callEnv env-th env_;
        env-attrs = env.passthru.attrs-post;
        split-env = split-import-attrs env-attrs;
        merged-specials = merge-special-attrs attrs split-env.specials;
        attrs-out = wDbg (split-env.non-specials // merged-specials) ;
        wDbg = attrs:
          let
            path = ["passthru" "import-data" ];
            old = attrByPath path null attrs;
            new = { inherit env attrs env-attrs split-env
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
          mergeattr  = name: { merge-import-value = merge-with-attr name;
                         default = {};};
          ignore = _: attrs: attrs;
          get-orig = name: attrs:
            attrByPath [name] (special-attr name).default attrs;
          merge-with-attr = name: value: attrs:
            let
              orig-value = get-orig name attrs;
              new-value = orig-value // value;
            in attrs // setAttrByPath [name] new-value;
          cat-with-default = name: value: attrs:
            let
              orig-value = get-orig name attrs;
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
          passthru = mergeattr "passthru";
          envs = keepattr;
        };
      defaults = mapAttrs (_: v: v.default) special-attr.definition;
    };

  }
