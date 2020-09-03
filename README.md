# `env-th`: For Writing Your n-th Environment

This package provides `mkEnvironment`, a nix utility for working
with `nix-shell` environments.

## Features

- Modular environments: Capture common tasks as libraries of shell
  functions. Import other `env-th` environments to inherit their
  libraries and variables.
- Environment Migration: All `env-th` environments inherit a standard
  library that includes basic utility functions, such as reloading
  the environment when a change is made to the environment definition.
  Another is the `env-ssh` function, which allows a user to ssh into
  the current environment on a foreign host.

## Introduction

The primary product of this `env-th` repository is a utility, `mkEnvironment`,
built on top of `stdenv.mkDerivation`, and providing a similar experience.
`mkEnvironment` derivations are used in conjunction with `nix-shell` in the
same way that `stdenv.mkDerivation` and `nix-shell` are used together when
developing a Nix package. However, whereas the point of `mkDerivation` is to
define the build process of a package, and `nix-shell` helps to achieve that
goal, the point of `mkEnvironment` is the `nix-shell` environment itself. Along
these lines, `mkEnvironment` provides an automatic build output--a script to
launch a shell session that replicates the `nix-shell` session of that
`mkEnvironment`. Ultimately this capability is used to providing `ssh`
connections into identical environments on foreign hosts.

## See Example in [env/sample/sample.nix](https://github.com/trevorcook/env-th/blob/master/envs/sample/sample.nix)

## Creating `env-th` Environments

To create an `env-th` environment, define a file, "`env.nix`" with a
form:
```
   {env-th ? default-envth [, ...] }: env-th.mkEnvironment { ... };
```
This form is a function where all arguments are provided defaults, and
the function body is the result of a call to `env-th.mkEnvironment`. The reason
for this convention is that it provides that the environment can be entered and
developed with `nix-shell env.nix` or imported inside the body of another
environment.

### Default Arguments

Default arguments can be supplied using something like the following
```
let pkgs = import <nixpkgs> { };
in { pkg1 ? pkgs.pkg1, pkg2 ? pkgs.pkg2 } :
```
[env/sample/sample.nix](https://github.com/trevorcook/env-th/blob/master/envs/sample/sample.nix) shows how a default `env-th` can be supplied by providing a `<nixpkgs>` overlay.

Alternatively, an overlay can be supplied in the user config directory (linux):
`~/.config/nixpkgs/overlays/env-th.nix`:
```
let
  env-th-src = builtins.fetchGit {
      url = https://github.com/trevorcook/env-th.git ;
      rev = "877caf9c6c8fe7c4edbf00e84b4655acda5f1487"; };
in
self: super: { env-th = import env-th-src self super; }
```

> Use `nix-prefetch-git https://github.com/trevorcook/env-th.git` to
acquire the recent rev

### Definition Body

There are two required attributes in every `mkEnvironment` derivation: `name`
and `defintion`. The `definition` attribute must be a nix path that refers to
the environment file itself, e.g. `./env.nix`.

> Note: nix paths are unquoted and have at least one '/'.


#### Attributes

- `lib`: The special attribute `lib`, if defined, should be a nix attribute set
  of string-valued attributes. Each attribute name will become a function in the
  resulting shell environment, the definition of which will be the attribute
  value. For example the following definition:
  ```
  lib = {
    list-param = ''
      echo "param 1 is $1"
      '';
    }
  ```
  will result in the following:
  ```
  > declare -f list-param
  list-param()
  {
    echo "param 1 is $1"
  }
  ```

- `imports`: If defined, `imports` should be a list of other `mkEnvironment`
  style derivations. E.g.:
  ```
  imports = [ ./a-env.nix
              ((import ./b-env.nix) { an-arg= "arg-value"; })
            ];
  ```
  In the above, `a-env.nix` will be imported using whatever packages are in
  scope for the in scope `env-th`. `b-env.nix` will be called using overloaded
  `an-arg` value.

  The libraries and variables of all imported environments will be added
  to the scope of the current environment. Later imports shadow earlier
  imports. A notable exception to this is `buildInputs`, whose definitions
  combine.

- Other `mkDerivation` attributes, i.e. `shellHook`, `buildInputs`, inherit    
  their behavior from `mkDerivation`. That is, `shellHook`, is run when the
  environment is entered, `buildInputs` are added to the `PATH` (for one). Any
  other attributes used by `mkDerivation` should probably work as well.

## Using the environment

When in the environment, the default library functions can be listed with
`env-0-lib`. Tab completion should work as well, `env-<tab><tab>`. Chief among
these functions are `env-build`, which is used to build the environment output,
and `env-reload`, which is used to update the environment based on changes
to its definition. Other notable functions are `env-ssh`, which is used to ssh
into foreign hosts (uses `NIX_SSHOPTS`) and `env-su` which is used to switch
user in the current environment.

### Localization

The default library function `env-localize` provides a means of copying
environment resources from the nix store. More precisely, it will copy any
file attribute in the environment that has been tagged with `mkSrc`, as in
```
  xFile = env-th.mkSrc ./xFile.md;
```
The copy will be placed relative to the `ENVTH_BUILDDIR`, which is the directory
of the `definition` file in the case of entering the environment through
`nix-shell` and is the current directory in the case of entering by invoking
the build product.

Resources can be referenced within the `mkEnvironment`. Using for instance,
`xFile.local` can be used to refer to the local file, while `xFile` for the
`/nix/store/` copy. 
