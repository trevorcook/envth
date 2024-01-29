# `envth`: For Writing Your n<sup>th</sup> Environment

This repository provides `mkEnvironment`, a [nix](https://nixos.org/) utility for creating modular `nix develop` style environments.

## Features

- Modular environments: Create environments to support specific needs. Import other `envth` environments to inherit their functionalities.
- Environment Migration: `envth` environments provide a build output that reproduces the `nix develop` environment of the nix definition. The output can be installed with `nix profile` or migrated between hosts using `envth` supplied functions based on `nix copy` (i.e. `envth ssh` allows direct deployment and connection into a foreign host).
- Scripting Support: `envth` will generate shell functions/commands based on user defined hooks. It integrates with [metafun](https://github.com/trevorcook/nix-metafun.git) for automatic generation of option parsing, help output, and tab completions.  

> Note: `envth` requires a working `nix` installation (available on Linux and macOS) with [flakes](nixos.wiki/wiki/Flakes) enabled. The `nix` based operating system, `nixOS`, is not required.

## Introduction

`envth` was designed to deploy operations to non-NixOS linux systems. An `envth` environment can be defined and tested locally then deployed directly to foreign (`nixpkgs` enabled) hosts. `envth` environments live in the nix store and do not modify an underlying system. They provide, however, a method by which functionality can be reliably distributed and may be used for anything from simulation deployment to ad-hoc system configuration.

This source repository hosts the "`envth`" library of nix expressions. The primary utility is `mkEnvironment`, built on top of `stdenv.mkDerivation`, and used in a similar fashion. That is, `mkEnvironment` derivations are used in conjunction with `nix develop` (formarly `nix-shell`) in the same way that `stdenv.mkDerivation` and `nix develop` are used together when developing a Nix package. However, whereas `mkDerivation` is used to define the build process of a package, and `nix develop` helps to achieve that goal, the goal of `mkEnvironment` is the `nix develop` environment itself.Consequently, unlike `mkDerivation`, `mkEnvironment` should be given no `builder`. Each environment automatically provides a build output--a script to launch a shell session that replicates the `nix develop` session of that `mkEnvironment`. This performs the basis for migrating shell sessions between hosts or using `nix profile` to install the environment.

## Example

Spawn an example environment in a new directory with the following.

```
> nix flake init -t github:trevorcook/envth#example
```

Run the example with `nix develop` or `nix develop --impure`.

You should be greeted with a prompt like:
```
[example]$USER@$HOST:dir$
```
Congratulations, you have entered your 1<sup>th</sup> `envth`. This environment inherits the basic `envth` functionality, which can be explored by using the `envth` command; for instance with `envth --help`. Notably, `envth` supports tab completion for subcommands and arguments and provides command line help for all subcommands.

Use `<ctrl-d>` or `exit` to return to your usual shell.

# Using Environments

Before getting into the details of how to define an environment, a quick tour of environment capabilites is in order. `envth` environments are just bash sessions with various envioronment variables set based on the definition: i.e. the variables and functions defined by the environment will be in scope, the packages declared in `paths` will be added to `PATH`, etc.

In addition to any shell functions defined in the environment (see `envlib` attribute), a function, `envfun-$name`, is generated for every environment. The function contains subcommands for listing information about the environment defintion, such as resources declared (`mkSrc`), sets of variables (`env-varsets`), or listing which functions have been defined. 

Each environment also generates the `envth` function, which provides an interface to `envfun-$name` functions for the current and all imported environments, as well as some additional functionality. Some of the more useful subcommands (`envth <cmd>`):

- `reload`: Reload the current environment, updating the definition if originally entered with `nix develop`
- `repl`: Load the current environment definition in a `nix repl` session.
- `ssh`: ssh to the current environment on a foreign host. Under the hood, this involves copying environment package followed by a ssh into an environment session.
- `varsets`: Manipulate the `env-varsets` defined in the environments.
- `localize`: Copy `mkSrc` tagged resources from the nix store to a local path; useful sometimes in conjunction with `envth ssh`.
- `enter`: Replace current environment with an in-scope environment (`env-addEnvs`).
- `install`: Add the current environment to the nix profile, essentially adding `enter-env-$name` to the user's path.

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

The overall form of the environment definition is a nix function. The arguments to the function declare which `nix` derivations the environment depends upon. The function body is the result of a call to `envth.mkEnvironment {...}`, where `{...}` contains all the environment definitions. The function-form is the standard `nix` idiom which allows the the modification of packages based on modification of their supplied inputs.

> Note: Within an environment, changes to the definition file will be realized after running the command `envth reload`. 

## `mkEnvironment` Definition Body

This section describes the attributes that can be passed to `envth.mkEnvironment`.

### Required Attributes

- `name`: The name of the environment. This attribute is required because of   the underlying implementation based on `mkDerivation`. It is also used in various ways. For example, the environment's build output will be  named `enter-env-${name}`, and a shell function, `envfun-${name}` is created for each environment. Also, users may add environments to `envth` and reference them by name:

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
    attribute sets compatible with the [metafun](https://github.com/trevorcook/nix-metafun.git) project. If supplied, metafun generated tab completion will also be exported for the attribute/function.

- `paths`: This attribute will add executables and libraries to the system
  paths as in `buildInputs` for `stdenv.mkDerivation` or `paths` for
  `nixpkgs.lib.buildEnv`. Therefore, to make software available within the
  environment, add the nix package to the definition file's input arguments
  and `paths`, e.g.:

  ```nix
  {envth,python3}:envth.mkEnvironment { /* ... */ paths = [python3];}
  ```

- `imports`: If defined, `imports` should be a list of other `mkEnvironment` style derivations, e.g.:

  ```nix
  { imports = [ ./a-env.nix
                (callPackage ./b-env.nix { an-arg= "arg-value"; })
                envth.envs.c-env
              ]; }
  ```
  In the above, `a-env.nix` will be imported using whatever packages are in scope for the in-scope `envth`. `b-env.nix` will be called using overloaded `an-arg` value, and `c-env` is an already in-scope environment.

  The libraries and variables of all imported environments will be added to the the current environment. Later imports shadow earlier imports, and the calling environment's variables shadow all imports. There are exceptions: `paths` and `envlibs` of imports are added to the current environment.

  > Note: An environment's `shellHook` will not be run when it is imported.
  The hook can be retrieved with, e.g., `otherHook = a-env.userShellHook`.

- `env-addEnvs`: This attribute expects a list of environments that will be brought into scope whenever the current environment is in scope. No environment variables are created with `env-addEnvs`, however "`passthru`" variables `envs` and `envs-added` can be inspected from within the `envth repl`. In addition, added environments can be entered from within the current environment with `envth enter <env>`, or from the command line with `nix develop .#<env>`. 

  > See also the section on `addEnvs` in [Other `envth` Utilities](other-envth-utilities).

- `env-varsets`: This attribute is used in conjunction with the environment function `envth varsets` to set predefined variables in the environment. The value should be a set of sets of string valued attributes.

  An example. With a definition including:
  ```nix
    { name = "myEnv";
      env-varsets = { set1 = { myvar = "value1";};
                      set2 = { myvar = "value2";}; }; }
  ```
  can be used during runtime with `envth varsets set set1`, for example.

- `env-projects`: This attribute expects a list of paths to environment definition files. Environment "projects" are `envth` environments not (necessarily) associated with a `nix flake`. Projects are expected to contain mutable data that should not be copied into the nix store (which happens in the case of flakes).Projects can be entered with `envth project enter <env>`, which changes the current directory to the project directory and enters the project environment. 

  > Note: when working with projects, `nix develop --impure` should be used.

- `shellHook`: As per the usual `shellHook`-`nix develop` functionality, this string-valued attribute can be used to run commands upon shell entry. Note that `envth` prepends the user supplied `shellHook` with additional commands. The original `shellHook` is exported as `userShellHook`

- Other `mkDerivation` attributes inherit their behavior from `mkDerivation`.  For instance, `buildInputs` are added to the `PATH` (for one). Any other attributes used by `mkDerivation`, (`src`, `unpackPhase`, etc.) might work as well, though they are untested and might not make sense in the `mkEnvironment` context.

- User defined attributes: Per the behavior of `mkDerivation` attribute sets, additional attributes will be exported to the resulting environment. For example, defining

  ```nix
  { NIX_SSHOPTS="-o ProxyJump=me@jumphost"; }
  ```
  will create the environment variable `NIX_SSHOPTS` (incidentally, this is passed to the underlying `scp/ssh` during `envth ssh`. This option, in particular, tunnels the copy through an intermediate host "`jumphost`"). 

  Note that any additional options must be coercable to strings (numbers, paths, sets with a `__toString` attribute, etc.).

# Other `envth` Utilities

The `envth` repository defines a nix attribute set containing a few utilities. The primary is `mkEnviornment` and has been discussed above in [Defining `envth` Environments](defining-envth-environments). The other attributes of note are discussed below.

> Note, these are attributes of the `envth` project itself--NOT attributes passed to `mkEnvironment`. They are used as in `envth.addEnvs` or `with envth; envs.some-env`

## `envs` and `addEnvs`

The `envth` library contains a bundle of environments `envth.envs`. When
`envth` is in-scope in a nix expression, the `envs` environments may be
referenced as well. For instance, the `sample` environment defines a variable,
`varSample1`, and can be referenced as in the following example:

```nix
  with envth; "varSample1 is: ${envs.sample.varSample1}"
```

Additional environments can be added to `envth.envs` by using `envth.addEnvs`. `addEnvs` expects a list of environments and returns a new `envth` with the added envs in `envth.envs`. The list of supplied environments may depend on the initial set of `envth.envs`, as well as environments appearing _before_ them in the list. For example, the following would add `./env-a.nix` to the set of environments, allowing it to be used in the subsequent definition.

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

`mkSrc` returns an attribute set containing the attribute `store` (among others). As a result, resources can be referenced within the `mkEnvironment` in two ways. Use the `store` attribute, e.g. `xFile.store`, to refer to the nix store copy of the file. Reference the return value, e.g. `xFile` for a path relative to the `definition` file.

Files are localized to a location corresponding to the local path supplied to `mkSrc`. The copy is placed relative to the `ENVTH_BUILDDIR`, which is the directory of the `definition` file (in the case of entering the environment through `nix develop`) or the current directory (in the case of entering by invoking the build product `enter-env-<name>`).

