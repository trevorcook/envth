# `envth`: For Writing Your n<sup>th</sup> Environment

This repository provides `mkEnvironment`, a [nix](https://nixos.org/) utility that creates derivations that replicate the `nix develop` (the Nix flake version of `nix-shell`) environment of their definition.

## Features

- Modular environments: Capture common tasks as libraries of shell functions. Import other `envth` environments to inherit their functionalities.
- Environment Migration: `envth` environments provide a build output that reproduces the `nix develop` environment of the nix definition. The output can be installed with `nix profile` and entered with `enter-env-<name>`, which is good for making project specific environments. Additionally, the standard `envth` shell library provides a function, `envth ssh`, that allows users to `ssh` into the current environment on a foreign host. Further functionality allows users to recreate files defined on the local host at the foreign host.

> Note: `envth` requires a working `nix` installation (available on Linux
  and macOS) with [flakes](nixos.wiki/wiki/Flakes) enabled. The `nix` based operating system, `nixOS`, is not required.

## Introduction

This repository hosts the "`envth`" library of nix expressions. The primary
utility is `mkEnvironment`, built on top of `stdenv.mkDerivation`, and used
in a similar fashion. That is, `mkEnvironment` derivations are used in
conjunction with `nix develop` (formarly `nix develop`) in the same way that `stdenv.mkDerivation` and `nix develop` are used together when developing a Nix package. However, whereas `mkDerivation` is used to define the build process of a package, and `nix develop` helps to achieve that goal, the goal of `mkEnvironment` is the `nix develop` environment itself.

Unlike `mkDerivation`, `mkEnvironment` should be given no `builder`. Each
environment automatically provides a build output--a script to
launch a shell session that replicates the `nix develop` session of that
`mkEnvironment`. This performs the basis for migrating shell sessions between
hosts or using `nix profile` to install the environment.

## Example

Spawn an example environment in a new directory with the following.

```
> nix flake init -t github:trevorcook/envth#example
```

Run the example with `nix develop`.

You should be greeted with a prompt like:
```
[example]$USER@$HOST:dir$
```
Congratulations, you have entered your 1<sup>th</sup> `envth`. This environment
inherits the basic `envth` functionality, which can be explored by using the
`envth` command; for instance with `envth --help`. Notably, `envth` supports tab completion for subcommands and arguments and provides command line help for all subcommands.

Use `<ctrl-d>` or `exit` to return to your usual shell.

# Defining `envth` Environments

## Templates

Environments should be initialized from the envth flake, either minimal (default) or full.

```
> nix flake init -t github:trevorcook/envth
> nix flake init -t github:trevorcook/envth#full
```

The flake file lists `nixpkgs` as an input and applies the `envth` library as an overlay. This allows environments to import other environments all based on a shared set of packages. The flake outputs packages, apps, and devShells for the named environment and the environmnets listed in it's `env-addEnvs` attribute.

## Environment Definition

To create an `envth` environment, we define environment files with the form
```nix
   { envth }: envth.mkEnvironment { /* ... */ }
```
The overall form of the environment definition is a function. The arguments to
the function declare which `nix` derivations the environment depends upon. The
function body is the result of a call to `envth.mkEnvironment {...}`, where
`{...}` contains all the environment definitions. The function-form is the
standard `nix` idiom which allows the the modification of packages based on
modification of their supplied inputs.

Within an environment, changes to the definition file will be realized after
running the command `envth reload`. 

## `mkEnvironment` Definition Body

This section describes the attributes that can be passed to
`envth.mkEnvironment`.

### Required Attributes

- `name`: The name of the environment. This attribute is required because of
  the underlying implementation based on `mkDerivation`. It is also used
  in various ways. For example, the environment's build output will be
  named `enter-env-${name}`, and a shell function, `envlib-${name}` is created for each environment. Also, users may add environments to `envth` and reference them by name:

  ```nix
  with (envth.addEnvs [ ./my-env.nix ]); mkDerivation {
   /* ... */
   thisattr = envs.my-env-name.thatattr;
  }
  ```
- `definition`: This attribute must be a nix path that refers to the
  environment file itself, and is required for `envth reload`.
  ```nix
  { definition = ./my-env.nix; }
  ```

### Other Attributes

- `envlib`: The special attribute `envlib`, if defined, should be a nix
  attribute set of string-valued* attributes. Each attribute name will become a
  function in the resulting shell environment, the definition of which will be
  the attribute value. For example the following definition:
  ```nix
  { envlib = { list-param = ''echo "param 1 is $1"''; }; }
  ```
  will result in the following:
  ```
  > declare -f list-param
  list-param()
  {
    echo "param 1 is $1"
  }
  ```
  * While the above is true, the attributes can also be
    attribute sets compatible with the [metafun](https://github.com/trevorcook/nix-metafun.git) project. If supplied, metafun generated
    tab completion will also be exported for the attribute/function.

- `paths`: This attribute will add executables and libraries to the system
  paths as in `buildInputs` for `stdenv.mkDerivation` or `paths` for
  `nixpkgs.lib.buildEnv`. Therefore, to make software available within the
  environment, add the nix package to the definition file's input arguments
  and `paths`, e.g.:

  ```nix
  {envth,python3}:envth.mkEnvironment { /* ... */ paths = [python3];}
  ```

- `imports`: If defined, `imports` should be a list of other `mkEnvironment`
  style derivations, e.g.:
  ```nix
  { imports = [ ./a-env.nix
                ((import ./b-env.nix) { an-arg= "arg-value"; })
              ]; }
  ```
  In the above, `a-env.nix` will be imported using whatever packages are in
  scope for the in scope `envth`. `b-env.nix` will be called using overloaded
  `an-arg` value.

  The libraries and variables of all imported environments will be added
  to the scope of the current environment. Later imports shadow earlier
  imports, and the calling environment's variables shadow all imports. There
  are exceptions: `paths` and `envlibs` of imported are added to the current
  environment.

  > Note: An environment's `shellHook` will not be run when it is imported.
  The hook can be retrieved with, e.g., `otherHook = envs.other.userShellHook`.

- `env-addEnvs`: This attribute expects a list of environments that will be   broughtinto scope whenever the current environment is in scope. No environment
   variables are created with `env-addEnvs`, however "`passthru`" variables `envs`
   and `envs-added` can be inspected from within the `envth repl`. See also the
   section on [other `envth` attributes](other-envth-attributes).

- `env-varsets`: This attribute is used in conjunction with the environment
  function `envth varsets` to set predefined variables in the environment.
  The value should be a set of sets of string valued attributes.

  An example. With a definition including:
  ```nix
    { name = "myEnv";
      env-varsets = { set1 = { myvar = "value1";};
                      set2 = { myvar = "value2";}; }; }
  ```
  can be used during runtime with `envth varsets set set1`, for example.


- `shellHook`: As per the usual `shellHook` `nix develop` functionality, this
  string-valued attribute can be used to run commands upon shell entry. Note
  that `envth` prepends the user supplied `shellHook` with additional commands.
  The original `shellHook` is exported as `userShellHook`

- Other `mkDerivation` attributes inherit their behavior from `mkDerivation`.
  For instance, `buildInputs` are added to the `PATH` (for one). Any
  other attributes used by `mkDerivation` might work as well, though they are
  untested and might not make sense in the `mkEnvironment` context.

- User defined attributes: Per the behavior of `mkDerivation` attribute sets,
  additional attributes will be exported to the resulting environment. For
  example, defining
  ```nix
  { NIX_SSHOPTS="-o ProxyJump=me@jumphost"; }
  ```
  will create the environment variable `NIX_SSHOPTS` (incidentally, this is
  passed to the underlying `scp/ssh` during `env-ssh`. This option, in
  particular, tunnels the copy through an intermediate host "`jumphost`").

  Note that any additional options must be coercable to strings (numbers,
  paths, sets with a `__toString` attribute, etc.).

# Other `envth` Attributes

The `envth` utility is a nix attribute set containing a few utilities. The primary is `mkEnviornment` and has been discussed above in [Defining `envth`
Environments](defining-envth-environments). The other attributes of note are
discussed below.

> Note, these are attributes of `envth` itself--NOT attributes passed to   
  `mkEnvironment`. They are used as in `envth.addEnvs` or
  `with envth; envs.some-env`

## `envs` and `addEnvs`

The `envth` library contains a bundle of environments `envth.envs`. When
`envth` is in-scope in a nix expression, the `envs` environments may be
referenced as well. For instance, the `sample` environment defines a variable,
`varSample1`, and can be referenced as in the following example:

```nix
  with envth; "varSample1 is: ${envs.sample.varSample1}"
```

Additional libraries can be added to `envth.envs` by using `envth.addEnvs`.
`addEnvs` expects a list of environments and returns a new `envth`. The list
of supplied environments may depend on the initial set of `envth.envs`, as well
as environments appearing _before_ them in the list. For example, the following
would add `./env-a.nix` to the set of environments, allowing it to be used in
the subsequent definition.
```nix
  {envth}: with envth.addEnvs [ ./env-a.nix ]; mkEnvironment {
    # ...
    env_a_definition = envs.env-a.definition;
  }
```
Note that `mkEnvironmnet` can be passed an `env-addEnvs` attribute ([Other Attributes](other-attributes)), which is different than, but works in conjunction
with `envth.addEnvs`. That attribute brings additional environments into scope
whenever the calling environment is brought into scope. For example, in the
sample environment, there is an `env-a.nix` which declares
`env-addEnvs = [./env-b.nix]`. In that case, `envth.addEnv [./env-a.nix]` would add
both `env-a` and `env-b` to the resulting `envs`.

## `mkSrc`

`envth.mkSrc` is used to tag files that may need to be "localized", that is,
copied from the nix store to the local filesystem using `envth localize`. The `mkSrc` utility is used within a `mkEnvironment` derivation in expressions such as the following attribute
defintion:
```nix
  { xFile = envth.mkSrc ./xFile.md; }
```
`mkSrc` expects a single path as an input. Files will be copied individually,
directories will be copied whole.

`mkSrc` returns an attribute set containing the attribute `store` (among
others). As a result, resources can be referenced within the `mkEnvironment` in
two ways. Use the `store` attribute, e.g. `xFile.store`, to refer to the nix store copy of the file. Reference the return value, e.g. `xFile` for a path relative to the `definition` file.

Files are localized to a location corresponding to the local path supplied to
`mkSrc`. The copy is placed relative to the `ENVTH_BUILDDIR`, which is the
directory of the `definition` file (in the case of entering the environment
through `nix develop`) or the current directory (in the case of entering by
invoking the build product `enter-env-<name>`).

# Using the environment

When in the environment, just go about your normal command-line shell business.
The variables and functions defined by the environment will be in scope, the
packages declared in `paths` will be added to `PATH`, etc.

In addition to those declared in `envlib`, an extra function, `envfun-$name`, is generated for every environment. The function contains subcommands for listing information about the environment defintion, and are used by the `envth` funciton in its operations.

The `envth` function is an enviornment function included in all `mkEnvironment` derivaitons. Some of the more useful subcommands:

- reload: Reload the current environment, updating the definition if originally entered with `nix develop`
- repl: Load the current environment in a `nix repl` session.
- ssh: ssh to the current environment on a foreign host. Under the hood, this involves copying environment package, followed by a ssh into an environment session.
- varsets: Manipulate the `env-varsets` defined in the environments.
- localize: Copy `mkSrc` tagged resources from the nix store to a local path; useful sometimes in conjunction with `envth ssh`.
- install: Add the current environment to the nix profile.
