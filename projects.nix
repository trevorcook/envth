{envth}: with builtins; with { inherit (envth.lib) callEnv; };
{
  add-projects = self: super@{env-projects?[],...}: {
      passthru = super.passthru // {
        projects = 
          let f = path: rec { name = value.env.name; 
                              value.env = callEnv path;
                              value.path = path; }; 
          in listToAttrs (map f env-projects);
        }; 
    };
}


      
