{lib}:
with lib;
rec {
  mkSrc = pth: rec {
      type = "env-resource";
      __toString = x: x.store;
      store = pth;
      local = toString pth;
    };
  isEnvSrc = attrs: (attrs ? type) && (attrs.type == "env-resource");

  mkLocalTo = ref: path:
    let
     toPath = concatStringsSep "/";
     ref' = splitString "/" ref;
     path' = splitString "/" path;
     mg0 = r: p:
       if p == [] then
         mg1 r [] ["."]
       else if r == [] then
         toPath p
       else
         let r0 = take 1 r;
             p0 = take 1 p;
         in if r0 == p0 then
              mg0 (drop 1 r) (drop 1 p)
            else
              mg1 r [] p;
      mg1 = r: acc: p:
       if r == [] then
        toPath (acc ++ p)
       else
        mg1 (drop 1 r) ([".."] ++ acc) p;
    in mg0 ref' path' ;

  gather-resources = self: attrs@{ENVTH_BUILDDIR, definition,...}:
    let attrs' = attrs // { definition = def-resource; };
        def-resource = mkSrc definition;
    in
      { ENVTH_RESOURCES =
        { resources = filterAttrs (_: v: isEnvSrc v) attrs';
          __toString = x:
              concatStringsSep " "
              (map (s: ''"${s.store} ${mkLocalTo ENVTH_BUILDDIR s.local}"'')
              (attrValues x.resources));
        };
        definition = mkLocalTo ENVTH_BUILDDIR def-resource.local;
      };

}
