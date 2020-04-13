Environments in this subdirectory will be picked up in the "envs" attribute
of `env-th`.

The directory name will become the sub-attribute of `envs`, e.g.
`env-th.envs.sample` for `envs/sample`. I suggest the convention of naming
the environment file after the environment `name` attribute and importing it
in `default.nix`. In any case `default.nix` should resolve to the environment
definition.

The reason for this convention is to avoid destructive overwrites when
"localizing" multiple environments into the same working directory. See
"sample/sample.nix" for a discussion of localization.
