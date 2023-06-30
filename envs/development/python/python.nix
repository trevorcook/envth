self: super: with self.lib;
let
  pyVersions = attrNames self.pythonIntrepreters;
  make-python-version = name:
    let python = (getAttr name self).withPackages (_:[]);
    in { inherit name;
         value = self.callPackage ./python-env.nix { inherit name python;};
       };
in listToAttrs (map make-python-version pyVersions)
