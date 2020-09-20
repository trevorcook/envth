self: super:
with builtins; with self.lib;
let
  unions = foldl' (new: acc: new // acc) {};
  callPackage = self.callPackage;
  mk-envs = name: value:
    let
      check = any (f: name == f);
      isDoNothing = check ["README.md" "default.nix"];
      returnsEnvsAttrs = check ["python"];
      returnsAnEnv = true;
    in if isDoNothing then
      {}
    else if returnsEnvsAttrs then
     import (./. + "/${name}") self super
    else #returnsAnEnv
      let env= callPackage (./. + "/${name}") {};
      in setAttrByPath [name] env;
in unions (mapAttrsToList mk-envs (readDir ./.))
