{callPackage}: with builtins;
let
  src = fetchGit {
    url = https://github.com/reflex-frp/reflex-platform.git;
    rev = "c13cb19f49c8093de4718d2aced1930128476cfa";
    /* sha256 = "0v87ilal9355xwz8y9m0zh14pm9c0f7pqch0854kkj92ybc5l62q"; */
    };
in callPackage src {}
