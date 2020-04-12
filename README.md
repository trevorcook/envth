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

Typically, a `mkEnvirnment` derivation contained in a file,
`env.nix`, will be used with `nix-shell`, e.g. `nix-shell env.nix`.
`mkEnvironment` builds off of `stdenv.mkDerivation`. Accordingly,
resources declared in `buildInputs` are made available in `PATH`,
attributes are exported as environment variables--and `mkEnvironment`
provides some additional capabilities. However, unlike `mkDerivation`,
`mkEnvironment` derivations automatically create a build output--
a program that recreates the `nix-shell env.nix`. The utility of
this output is to migrate environments between hosts, ultimately
providing for `ssh` connections into identical environments on
foreign hosts.

# See env/sample.nix to get started
