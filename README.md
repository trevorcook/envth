# `envth`: For Writing Your n<sup>th</sup> Environment

This repository provides `mkEnvironment`, a [nix](https://nixos.org/) utility that creates derivations that replicate the `nix-shell` environment of their definition.

## Features

- Modular environments: Capture common tasks as libraries of shell   functions. Import other `envth` environments to inherit their   functionalities.
- Environment Migration: `envth` environments provide a build output that reproduces the `nix-shell` environment of the nix definition. The output can be installed with `nix-env` and entered with `enter-env-<name>`. Additionally, the standard `envth` shell library provides a function, `envth ssh`, that allows users to `ssh` into the current environment on a foreign host. Further functionality allows users to easily recreate files in the local host at the foreign host.

> Note: `envth` requires a working `nix` installation (available on Linux
  and macOS). The `nix` based operating system, `nixOS`, is not required.

## Introduction

This repository hosts the "`envth`" library of nix expressions. The primary
utility is `mkEnvironment`, built on top of `stdenv.mkDerivation`, and used
in a similar fashion. That is, `mkEnvironment` derivations are used in
conjunction with `nix-shell` in the same way that `stdenv.mkDerivation` and
`nix-shell` are used together when developing a Nix package. However, whereas
`mkDerivation` is used to define the build process of a package, and
`nix-shell` helps to achieve that goal, the goal of `mkEnvironment` is the
`nix-shell` environment itself.

Unlike `mkDerivation`, `mkEnvironment` should be given no `builder`. Each
environment automatically provides a build output--a script to
launch a shell session that replicates the `nix-shell` session of that
`mkEnvironment`. This performs the basis for migrating shell sessions between
hosts or using `nix-env` to install the environment.

## Minimal Example

Copy and paste the following into the command line. It creates two files--
`shell.nix` and `env-1.nix`--in the current directory and launches a nix shell.
You might want to create and move to a new directory first.

```
cat >env-1.nix <<'EOF'
{ envth }: with envth;
mkEnvironment {
 name = "env-1";
 definition = ./env-1.nix;
 }
EOF
cat >shell.nix <<'EOF'
let
  envth-src = builtins.fetchGit {
      url = https://github.com/trevorcook/envth.git ;
      rev = "159b735525b6d9e7396749e3dd64a24c7570ce0c"; };
  envth-overlay = self: super: { envth = import envth-src self super; };
  nixpkgs = import <nixpkgs> { overlays = [ envth-overlay ]; };
in {definition ? ./env-1.nix}: nixpkgs.callPackage definition {}
EOF
nix-shell

```

You should be greeted with a prompt like:
```
[env-1]$USER@$HOST:dir$
```
Congratulations, you have entered your 1<sup>th</sup> `envth`. This environment
inherits the basic `envth` functionality, which can be explored by using the
command `env-lib`, for example. Use `<ctrl-d>` or `exit` to return to your usual
shell.

### Explanation

In the above code, the lines between the `EOF` are "Here documents". They get
piped verbatim into the standard `cat` utility, which then saves them as
`shell.nix` and `env-1.nix`.

The environment definition is contained in `env-1.nix`. It is defined in the
standard nix package-as-a-function idiom, with a lone dependency, `envth`,
specified by its input arguments. The `with` expression brings `mkEnvironment`
into scope, and `mkEnvironment` makes a shell environment named "`env-1`" and
whose definition is the current file, `env-1.nix`.

The file, `shell.nix`, is called by `nix-shell`, and uses `callPackage` to
satisfy the dependencies defined in `env-1.nix`. In `shell.nix` the `let`
bindings add the `envth` attribute set to `<nixpkgs>` so that `callPackage`
knows about it. An idiosyncrasy of this `shell.nix` is that it is
defined as a function with a default argument. This provides compatibility
between invoking the definition with `nix-shell` from outside the environment
and `env-reload` from inside the environment.

## Maximal Example

We can initialize a more sophisticated example, [env/sample/sample.nix](https://github.com/trevorcook/envth/blob/master/envs/sample/sample.nix), by copying the following to the command line. Again, you should do this in a new directory.

```
cat >shell.nix <<'EOF'
let
  envth-src = builtins.fetchGit {
      url = https://github.com/trevorcook/envth.git ;
      rev = "159b735525b6d9e7396749e3dd64a24c7570ce0c"; };
  envth-overlay = self: super: { envth = import envth-src self super; };
  nixpkgs = import <nixpkgs> { overlays = [ envth-overlay ]; };
in {definition ? ./sample.nix}: nixpkgs.callPackage definition {}
EOF
cat >sample.nix <<'EOF'
{envth}: envth.envs.sample
EOF
nix-shell

```
The shell will be launched and greet you with a message explaining what to do
next. The result should be the definition files written to your directory.
Perusing those files will demonstrate the concepts that are also explained
in the sequel of this README.

### Explanation

Like in the minimal example, this code creates two files, a `shell.nix` that
calls the definition, `sample.nix`. The only difference in the `shell.nix` here
is the default `definition` supplied. The definition file however, just
references the included environment, `envth.envs.sample`, rather than defining
a new one.

On entering the shell, a message is printed that suggests different commands to
run. One, `env-localize`, will copy the definition files from the nix store
to the local directory. Part of this is replacing the original `sample.nix` with
the original definition on which it is based. The next time the shell is entered,
it will be using the local definition.

# Defining `envth` Environments

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

## Loading Environments and Default Arguments

Invoking an environment directly from `nix-shell` is only possible if all the
input arguments are satisfied with defaults. To avoid supplying all the
arguments by hand, `envth` environments can be called with `callPackage` from a
`shell.nix`, as demonstrated in the [Minimal](minimal-example) and
[Maximal](maximal-example) examples.

Within an environment, changes to the definition file will be realized after
running the command `env-reload`. This command has access to a default,
`envth`-generated, `shell.nix` type file that uses a `callPackage` to call the
definition. Please note that the behavior of the environment may differ when
invoked via `nix-shell` or `env-reload`, depending on the difference between the
user supplied `shell.nix` and `envth`'s own internal `shell.nix`. This behavior
can be controlled by the `mkEnvironment` attribute `env-caller`, and is
discussed in [other attributes](other-attributes).

### User Overlay

To provide the `envth` input to our environments we defined overlays
in our example `shell.nix` files. Instead of providing that overlay in each
file, one can be supplied in the user's nixpkgs config file. Doing so
will add the `envth` attribute to `<nixpkgs>` any time it is invoked, and
therefore make it available with `callPackages`.

For linux, add the following to `~/.config/nixpkgs/overlays/envth.nix`:
  ```nix
  let
    envth-src = builtins.fetchGit {
        url = https://github.com/trevorcook/envth.git ;
        rev = "159b735525b6d9e7396749e3dd64a24c7570ce0c"; };
  in
  self: super: { envth = import envth-src self super; }
  ```
> Note: Use `nix-prefetch-git https://github.com/trevorcook/envth.git` to get
  the recent `rev`
> See [nixos wiki](https://nixos.wiki/wiki/Overlays) for alternative overlay
  methods.

## `mkEnvironment` Definition Body

This section describes the attributes that can be passed to
`envth.mkEnvironment`.

### Required Attributes

- `name`: The name of the environment. This attribute is required because of
  the underlying implementation based on `mkDerivation`. It is also used
  in various ways. For example, the environment's build output will be
  named `enter-${name}`, and various shell functions, `${name}-`, will be
  created. Also, users may add environments to `envth` and reference them
  by name:
  ```nix
  with (envth.addEnvs [ ./my-env.nix ]); mkDerivation {
   /* ... */
   thisattr = envs.my-env-name.thatattr;
  }
  ```
- `definition`: This attribute must be a nix path that refers to the
  environment file itself.
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
  * While the above is essentially true, the attributes can also be
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

- `env-addEnvs`: This attribute expects a list of environments that will be brought
   into scope whenever the current environment is in scope. No environment
   variables are created with `env-addEnvs`, however "`passthru`" variables `envs`
   and `envs-added` can be inspected from within the `nix repl`. See also the
   section on [other `envth` attributes](other-envth-attributes).

- `env-caller`: `envth` creates a nix file that calls the `definition` with
  `callPackages`. This is used by some `env0`-supplied `envlib` functions,
  including `env-reload` and `env-repl`.

  To supply an alternative reloader, assign `env-caller` to the filepath of
  a nix file of the form `{definition}:callPackage definition {}`. The location
  of the caller file will be held in the runtime environment variable
  `ENVTH_CALLER`. Alternative forms of `env-caller` include the string "none"--
  in which case the expression `{definition}: definition {}` will be used as
  the caller--or a set including the attribute `definition` and attributes
  for inputs to the definition.

  In particular, `env-caller`, should be supplied in cases where a nix file
  more complicated than `with import <nixpkgs> {}; callPackage ./def.nix {}`
  is needed.

- `env-varsets`: This attribute is used in conjunction with the environment
  function `${name}-setvars` to set predefined variables in the environment.
  The value should be a set of sets of string valued attributes.

  An example. With a definition including:
  ```nix
    { name = "myEnv";
      env-varsets = { set1 = { myvar = "value1";};
                      set2 = { myvar = "value2";}; }; }
  ```
  The environment will include a function `myEnv-setvars`. Invoking
  `myEnv-setvars set1` will result in the variable `myvar=value1`. Invoking
  `myEnv-setvars set2` yields `myvar=value2`.


- `shellHook`: As per the usual `shellHook` `nix-shell` functionality, this
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

`envth` is a nix expression containing a few utilities. The primary is
`mkEnviornment` and has been discussed above in [Defining `envth`
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
copied from the nix store to the local filesystem. This utility is used within
a `mkEnvironment` derivation in expressions such as the following attribute
defintion:
```nix
  { xFile = envth.mkSrc ./xFile.md; }
```
`mkSrc` expects a single path as an input. Files will be copied individually,
directories will be copied whole.

`mkSrc` returns an attribute set containing the attribute `local` (among
others). As a result, resources can be referenced within the `mkEnvironment` in
two ways. Use the `local` attribute, e.g. `xFile.local`, to refer to the local
copy of the file. Reference the return value, e.g. `xFile`, or the `store`
attribute to reference the `/nix/store/` copy.

Files are localized to a location corresponding to the local path supplied to
`mkSrc`. The copy is placed relative to the `ENVTH_BUILDDIR`, which is the
directory of the `definition` file (in the case of entering the environment
through `nix-shell`) or the current directory (in the case of entering by
invoking the build product `enter-<name>`).

# Using the environment

When in the environment, just go about your normal command-line shell business.
The variables and functions defined by the environment will be in scope, the
packages declared in `paths` will be added to `PATH`, etc.

Extra functions in addition to those declared in `envlib` are defined
for every environment. These functions all begin with the environment name,
and can be viewed with tab completion: `${name}-<tab><tab>`.  

- `${name}-env-lib`: Lists all functions defined by this environment.
- `${name}-env-localize`: Localizes all `mkSrc` resources based on the current
   environment's build directory.
- `${name}-env-localize-to`: Localizes all `mkSrc` resources based on a supplied
   directory.
- `${name}-env-setvars`: Set variables defined in the environment's `env-varsets`.
- `${name}-env-vars`: Show the variables set by attributes of the environment.


Default library functions are supplied by an included "`env0`", and can be
listed with `env0-lib`. Tab completion should work as well, `env-<tab><tab>`.

Some of the more important functions are `env-build`, which is used to build
the environment output, and `env-reload`, which is used to update the
environment based on changes to its definition. Other notable functions are
`env-ssh`, which is used to ssh into foreign hosts (uses `NIX_SSHOPTS`) and
`env-su` which is used to switch user in the current environment.

## Installing

Environments can be installed using `nix-env`. For instance, the currently
active environment can be installed with `nix-env -if $definition`. This will
add the executable `enter-<name>` to the current user's PATH.

## Localization

The default library function `env-localize` provides a means of copying
environment resources from the nix store. More precisely, it will copy the
definition file and any file attribute in the environment that has been tagged with `mkSrc`, as in
```nix
  { xFile = envth.mkSrc ./xFile.md; }
```
The copy will be placed relative to the `ENVTH_BUILDDIR`, which is the directory
of the `definition` file (in the case of entering the environment through
`nix-shell`) or the current directory (in the case of entering by invoking
the build product).
