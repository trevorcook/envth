self: super:
with self.lib;
let callPackage = self.callPackage;
in rec {

  nixpkgs = import <nixpkgs> {};
  env-0 = mkEnvironment env-0-attrs;
  env-1 = mkEnvironment { name = "env-1"; definition = ./env-1.nix;
                          imports = [ ./env-2.nix ];
                          shellHook = "echo env-1 shellHook";
                          var_env1 = "varenv-1";
                          lib = { hey-1 = "echo hello from env-1";}; };
  env-2 = mkEnvironment { name = "env-2"; definition = ./env-2.nix;
                          var_env1 = "varenv-2";
                          var_env2 = "varenv-2";
                          lib = { hey-1 = "echo hello from env-    2";
                                  hey-2 = "echo hello from env-    2";
                                };
                        };
  env-0-attrs = { name = "env-0";
                  definition = ./env-0.nix;
                  src1 = mkSrc ./src1;
                  resource = mkSrc ./resource.txt;
                  lib = { hi = "echo hi";
                          show-vars = "echo VARS";
                        };
                  var_env1 = "varenv-0";
                  imports = [ ./env-1.nix ];
                  shellHook = ''
                  cat <<EOF
                  ${lib.show-vars-current [
                                            /* "ENVTH_BUILDDIR" */
                                            /* "ENVTH_ENTRY" */
                                            /* "ENVTH_DRV" */
                                            /* "this_enter_env" */
                                            "definition"
                                            "imports"
                                            "lib"
                                            "import_names"
                                            "import_libs"
                                            "import_shellHooks"
                                            "var_env1"
                                            "var_env2"
                                            "importLibsHook"
                                          ]}
                  EOF
                  #env-build
                  '';
                  buildInputs = [];
                };

  init-attrs = callPackage ./init-attrs.nix {};
  init-env = callPackage ./init-env.nix {};

  imports = callPackage ./imports.nix {};
  builder = callPackage ./build.nix {};
  resources = callPackage ./resources.nix {};
  mkSrc = ((callPackage ./resources.nix) {}).mkSrc;

  lib = callPackage ./lib.nix {};
  mkEnvironment = (callPackage ./mkEnvironment.nix { }).mkEnvironment;
}
