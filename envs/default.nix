self: super:
with builtins; with self.lib;
let
  unions = foldl' (new: acc: new // acc) {};
  callPackage = self.callPackage;
  mk-envs = name: value:
    let
      check = any (f: name == f);
      # Add here any files that should be ignored as environments
      isDoNothing = check ["README.md" "default.nix"];
      # Add here any dirs/files with type: self -> super -> attrs_of_envs
      returnsEnvsAttrs = check ["python"];
      # Default behavior for dirs/files where callPackage returns an env.
      callAnEnv = true;
    in if isDoNothing then
      {}
    else if returnsEnvsAttrs then
     import (./. + "/${name}") self super
    else #callAnEnv
      let env= callPackage (./. + "/${name}") {};
      in setAttrByPath [name] env;
in unions (mapAttrsToList mk-envs (readDir ./.))
