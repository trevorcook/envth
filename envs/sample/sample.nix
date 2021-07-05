{envth , figlet }: with envth.addEnvs [ extra-envs/env-a.nix ];
mkEnvironment rec {

  # REQUIRED ARGS ####################

  # Used to determine output name:
  #    $out/bin/enter-env-$name
  name = "sample";
  # Must refer to itself.
  definition = ./sample.nix;

  # OPTIONAL ##########################

  # Non-special variables #############
  # As usual, environment variables can be defined with attributes.
  # Note that all (non-special) variables should be coercible to a string.
  varSample1 = "sample VAR1";
  varSample2 = https://nixos.org;
  varSample3 = [ "a" "b" ];
  varSample4 = { __toString = _ : "I have a nix expression.";
           dat = x: "x = ${x}"; };

  # The following attributes demonstrate `envth.mkSrc`, a utility
  # used to tag resources which can be "localized", that is, copied
  # from /nix/store to a local directory. Localized resources will
  # have the same file structure as the original.
  # In the running environment, the following variables will point
  # to locations in /nix/store. The resources can be localized from
  # within the running environment with `env-localize`
  b_file = mkSrc ./b-dir/b-file.txt;
  extra_envs = mkSrc ./extra-envs;


  # Special variables ################
  # These variables are treated specially in various ways.

  # paths will add utilities to the environment path.
  paths = [ figlet ];

  # Commands to run upon shell entry.
  shellHook = ''
    b_file="no/such/file"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | lolcat
    sample-banner envth
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | lolcat
    cat <<'EOF'
    Hello from ${name}!

    Use functions defined by this environment, e.g.

    > sample-banner MAMA

    Inspect the list of all imported functions with

    > env-lib

    (Note the URI printed last. It is a html page where all the
    sources of all the imported functions can be inspected.)

    Copy the files defining this environment into the current
    directory with:

    > env-localize

    Inspect "sample.nix", make changes as desired, and reload
    with

    > env-reload
    EOF
    '';

  # The `lib` attribute should be a set of text valued attributes.
  # Each attribute name becomes a shell function of the same name.
  # The values become the contents of the function.
  # mkEnvironment also adds two functions, ${name}-lib and ${name}-vars
  # which list the defined functions and vars (respectively).
  envlib = {
    sample-function-1 = ''
      echo this is function one, with args "$@"
      '';
    # the following demonstrates how localized files might be
    sample-show-b-file = ''
      cat <<EOF
      In function show-b-file
      \''${b_file} is ${b_file}
      \''${b_file.local} is ${b_file.local}
      However, b_file is currently $b_file
      EOF
      '';
    sample-banner = ''
    #This function uses "figlet" put on the path in this environment
    # and "lolcat" inherited from `env-c.nix`;
    echo "$*" | figlet | lolcat
    '';
  };
  # mkEnvironment imports an initial environment, env-0, which
  # contains useful utilities. Try
  # > env-0-lib
  # to list contained functions.

  # imports: A list of environments to be merged with the current one.
  # Attributes, `paths` `envlib` of imported are added to the environment.
  # The `imports` are added in order they are listed, so any later
  # imports will override earlier variables and functions of the
  # same name. Additionally, `imports` creates a special attribute
  # `import_libs`, listing all the `libs` of imported environments.
  imports = [
    envs.env-a # env-a is merged into envth.envs on line 10 of this file.
               # Its definition is in scope, this line merges it with the
               # current environment.
    extra-envs/env-c.nix  # path to env file will be loaded using callPackage
    ];

  # env-addEnvs: Export extra environments.
  # Using `envth.addEnvs`, as seen at the top of this file, will bring
  # additional environments into scope so that they can be referenced
  # within the nix definition file. Declaring an `env-addEnvs` attribute, such as
  # below, puts extra environmnets in scope whenever the calling environment is
  # in scope.
  # For example, both `env-a` and `env-c` declare `env-addEnvs`--for env-b and
  # env-c, respectively. `env-a` is brought into scope at the top of this file
  # and so its exported environments--`env-b` in this case--may be referenced.
  # see?
  varB_referenced = envs.env-b.varB;
  # `env-c` is never brought into scope, and so its exported reference,
  # `env-d`, is not either. Neither `envs.env-c` nor `envs.env-d` can be
  # referenced.
  # In a similar vein to the above explanation, the following attribute
  # would put both `env-a` and `env-b` in scope whenever envs.sample is put in
  # scope.
  # env-addEnvs = [ envs.env-a ];
  # All environments inherit an `env` attribute (passthru.env, actually),
  # listing all in scope envs. All in-scope environments can be inspected
  # with nix read-eval-print-loop utility. E.g.
  # > env-repl  or
  # > nix repl ./shell.nix
  # nix-repl> passthru.envs
  # { env-a = <<derivation.... }
  # nix-repl> passthru.envs.env-b.<tab>
  # etc.

  # env-varsets: use the command
  # > sample-setvars varset-new
  # to set the environment variables to "new ..." values.
  # use:
  # > sample-setvars varset-revert
  # to set those variables to the values found in the original environments.
  env-varsets = {
    varset-new = { varA = "new varA set in sample.nix";
                   varB = "new varB set in sample.nix"; };
    varset-revert = { varA = envs.env-a.varA;
                      varB = envs.env-b.varB; }; };

}
