# `env-th`: For Writing Your n-th Environment

This package provides `mkEnvironment`, a nix utility for building
derivations specialized for working in `nix-shell` environments.

Typically, a `mkEnvirnment` derivation contained in a file,
`env.nix`, will be used with `nix-shell`, e.g. `nix-shell env.nix`.
Like typical `mkDerivation` environments, `mkEnvironment` ensures
required resources declared in `buildInputs` are present, attributes
are exported as environment variables--as well as providing some
additional capabilities. However, unlike `mkDerivation`,
`mkEnvironment` derivations automatically create a build output,
a program that recreates the `nix-shell env.nix`. The utility of
this output is to migrate environments between hosts, ultimately
providing for `ssh` connections into identical environments on
foreign hosts.
