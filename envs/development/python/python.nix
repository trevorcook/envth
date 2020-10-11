self: super: with self.lib;
let
  pyVersions = [ "python"
                 "python2" "python27"
                 "python3" "python35" "python36" "python37" "python38" "python39"
               ];
  make-python-version = name:
    let python = (getAttr name self).withPackages (_:[]);
    in { inherit name;
         value = self.callPackage ./python-env.nix { inherit name python;};
       };
in listToAttrs (map make-python-version pyVersions)
