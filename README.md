# `env-th`: For Writing Your n<sup>th</sup> Environment

This repository provides `mkEnvironment`, a [nix](https://nixos.org/) utility
for working with `nix-shell` environments.

## Features

- Modular environments: Capture common tasks as libraries of shell
  functions. Import other `env-th` environments to inherit their
  libraries and variables.
- Environment Migration: The standard `env-th` environment library includes
  a function, `env-ssh`, that allows a user to `ssh` into the current
  environment on a foreign host.

> Note: `env-th` requires a working `nix` installation (available on Linux
  and macOS). It will, of course, work within the `nixOS` operating system,
  but that is not required.

## Introduction

This repository hosts the "`env-th`" library of nix expressions. The primary
utility is `mkEnvironment`, built on top of `stdenv.mkDerivation`, and used
in a similar fashion. That is, `mkEnvironment` derivations are used in
conjunction with `nix-shell` in the same way that `stdenv.mkDerivation` and
`nix-shell` are used together when developing a Nix package. However, whereas
`mkDerivation` is used to define the build process of a package, and
`nix-shell` helps to achieve that goal, the goal of `mkEnvironment` is the
`nix-shell` environment itself.

Unlike `mkDerivation`, `mkEnvironment` requires no `builder`. In fact, each
environment automatically provides a build output--a script to
launch a shell session that replicates the `nix-shell` session of that
`mkEnvironment`. This performs the basis for migrating shell sessions between
hosts or using `nix-env` to install the environment.

## Minimal Example

Save the following code to a file, `env-1.nix`, then launch
`nix-shell env-1.nix`.

```
let
  # Source from Github
  env-th-src = builtins.fetchGit {
      url = https://github.com/trevorcook/env-th.git ;
      rev = "877caf9c6c8fe7c4edbf00e84b4655acda5f1487"; };
  # An overlay to to include env-th
  env-th-overlay = self: super: { env-th = import env-th-src self super; };
  # import nixpkgs extended to include env-th
  nixpkgs = import <nixpkgs> { overlays = [ env-th-overlay ]; };
in
{ env-th ? nixpkgs.env-th }: with env-th;
mkEnvironment {
 name = "env-1";
 definition = ./env-1.nix;
 }
```

You should be greeted with a prompt like:
```
[env-1]$USER@$HOST:dir$
```
Congratulations, you have entered your 1<sup>th</sup> `env-th`

For a more comprehensive example, see [env/sample/sample.nix](https://github.com/trevorcook/env-th/blob/master/envs/sample/sample.nix)

## Creating `env-th` Environments

To create an `env-th` environment, we define environment files with the form
```
   {env-th ? default-envth [, ...] }: env-th.mkEnvironment { ... };
```
In this form, the environment definition is a function where all the input
arguments are provided default values. The function body is the result of a
call to `env-th.mkEnvironment {...}`, where the contents of (`{...}`) hold all
the environment definitions. The reason for the "function with defaults"
convention is that it both provides that the environment can be entered with
`nix-shell env.nix` and that it can be imported inside the body of another
environment.

### Default Arguments

Default arguments can be supplied using something like the following
```
let pkgs = import <nixpkgs> { };
in { pkg1 ? pkgs.pkg1, pkg2 ? pkgs.pkg2 } :
```
The above demonstration of `env-1` shows shows how a default `env-th` can be
supplied by providing a `<nixpkgs>` overlay. Alternatively, an overlay can be
supplied in the user config directory:
  (linux):
   `~/.config/nixpkgs/overlays/env-th.nix`:
  ```
  let
    env-th-src = builtins.fetchGit {
        url = https://github.com/trevorcook/env-th.git ;
        rev = "b4836bae89263d9cc70e883f21fffaed9e296272"; };
  in
  self: super: { env-th = import env-th-src self super; }
  ```
> Use `nix-prefetch-git https://github.com/trevorcook/env-th.git` to get
  the recent `rev`

### Definition Body

#### Required Attributes

There are two required attributes in every `mkEnvironment` derivation: `name`
and `defintion`. The `definition` attribute must be a nix path that refers to
the environment file itself.

#### Other Attributes

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

- Other `mkDerivation` attributes, i.e. `shellHook`, `buildInputs`, inherit    
  their behavior from `mkDerivation`. That is, `shellHook`, is run when the
  environment is entered, `buildInputs` are added to the `PATH` (for one). Any
  other attributes used by `mkDerivation` should probably work as well.

> The libraries and variables of all imported environments will be added
  to the scope of the current environment. Later imports shadow earlier
  imports. A notable exception to this is `buildInputs`, whose definitions
  combine.

- User defined attributes: Per `mkDerivation` attribute sets, additional
  attributes will be exported to the resulting environment. For example,
  defining
  ```
  NIX_SSHOPTS="-o ProxyJump=me@jumphost";
  ```
  will create the environment variable `NIX_SSHOPTS`, which incidentally is
  passed to the underlying `scp/ssh` during `env-ssh`. This option, in
  particular, tunnels the copy through an intermediate host "`jumphost`".

  Note that any additional options must be coercable to strings (numbers,
  paths, sets with a `__toString` attribute, etc.).

## Using the environment

When in the environment, just go about your normal command-line shell business.
The variables and functions defined by the environment will be in scope. The
default library functions can be listed with `env-0-lib`. Tab completion should
work as well, `env-<tab><tab>`.

Some of the more important functions are `env-build`, which is used to build
the environment output, and `env-reload`, which is used to update the
environment based on changes to its definition. Other notable functions are
`env-ssh`, which is used to ssh into foreign hosts (uses `NIX_SSHOPTS`) and
`env-su` which is used to switch user in the current environment.

### Localization

The default library function `env-localize` provides a means of copying
environment resources from the nix store. More precisely, it will copy any
file attribute in the environment that has been tagged with `mkSrc`, as in
```
  xFile = env-th.mkSrc ./xFile.md;
```
The copy will be placed relative to the `ENVTH_BUILDDIR`, which is the directory
of the `definition` file (in the case of entering the environment through
`nix-shell`) or the current directory (in the case of entering by invoking
the build product).

Resources can be referenced within the `mkEnvironment` in two ways. Using, for
instance, `xFile.local` can be used to refer to the local file, while `xFile`
refers to the `/nix/store/` copy.
