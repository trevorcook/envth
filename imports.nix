{callPackage, lib, envth}: with builtins; with lib;
with envth.lib;
let
  # unique list, keeping last instances in list.
  uniquer = ls: reverseList (unique (reverseList ls));
in
rec
  {
    # Add imports overlay
    add-imports = self: {imports ? [],...}@attrs:
      let
        merged-attrs = foldr merge-import-env attrs ([env0] ++ imports);
        merged-imports = [env0] ++ attrByPath ["imports"] [] merged-attrs;
      in merged-attrs // {
          passthru = merged-attrs.passthru
                  // { envs-imported = map (callEnv envth) merged-imports; };};

    # Merge an imported env into the current attribute set.
    merge-import-env = env_: attrs:
      let
        env = callEnv envth env_;
        env-attrs = restrict-passthru-attrs env.passthru.attrs-post;
        restrict-passthru-attrs = env: env // {
          passthru = filterAttrs
            (n: v: all (k: k != n) ["envs" "envs-added" "envs-orig"
                                    "envs-imported" "attrs-pre"] )
            env.passthru;
          };
        split-env = split-import-attrs env-attrs;
        merged-specials = merge-special-attrs attrs split-env.specials;
        attrs-out = split-env.non-specials // merged-specials ;
        /* attrs-out = wDbg (split-env.non-specials // merged-specials) ; */
        /* wDbg = attrs:
          let
            path = ["passthru" "import-data" ];
            old = attrByPath path null attrs;
            new = { inherit env attrs env-attrs split-env
                            merged-specials env_ attrs-out;
                    importing-name = env-attrs.name;
                    import-data = old; };
          in attrs; #recursiveUpdate attrs (setAttrByPath path new); */
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
              new-value = recursiveUpdate orig-value value;
            in attrs // setAttrByPath [name] new-value;
          cat-with-default = name: value: attrs:
            let
              orig-value = get-orig name attrs;
              new-value = uniquer (orig-value ++ value);
            in attrs // setAttrByPath [name] new-value;
        in {
          paths = catlist "paths";
          #ADDENVS rename
          /* addEnvs = keeplist; */
          env-addEnvs = keeplist;
          ###
          name = keepstring;
          definition = keepstring;
          envlib = keepattr;
          import_libs = catlist "import_libs";
          shellHook = keepstring;
          imports = catlist "imports";
          passthru = mergeattr "passthru";
          envs = keepattr;
        };
      defaults = mapAttrs (_: v: v.default) special-attr.definition;
    };

  }
