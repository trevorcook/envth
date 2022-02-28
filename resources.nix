{lib}:
with lib;
rec {
  mkSrc = pth: if isEnvSrc pth then pth else
    let self = {
          type = "env-resource";
          __toString = x: x.local;
          store = pth;
          local = toString pth;
        };
    in self // { store = self // { __toString = x: x.store; }; };

  isEnvSrc = attrs: (attrs ? type) && (attrs.type == "env-resource");

  mkRelativeTo = ref: path:
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

  filter-resources = filterAttrs (_: v: isEnvSrc v);
  no-resources = { resources = {}; __toString = _: ""; };

  get-localized-resources =  attrs@{ENVTH_BUILDDIR, definition,...}:
    let rsrcs = filterAttrs (_: isEnvSrc) attrs
             // { definition = mkSrc attrs.definition; };
        mk-relative = rsrc: rsrc //
          { local = mkRelativeTo ENVTH_BUILDDIR rsrc.local; };
    in mapAttrs (_: mk-relative) rsrcs;


  gather-resources = self: attrs@{ENVTH_BUILDDIR, definition,...}:
    let resources = get-localized-resources attrs;
    in
      resources // {
        ENVTH_RESOURCES = {
          inherit resources;
          __toString = x:
              concatStringsSep " "
              (mapAttrsToList (n: v:  ''"${v.store} ${v.local}"'')
              x.resources);
        };
      };
}
