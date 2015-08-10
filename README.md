# DependenciesTree
After compiling the package you can use the code bellow to call the procedure 
```PLSQL
begin
-- Call the procedure
p_Dependencies.printDependencies(av_schema => &param_schema&,
								av_type => &param_type&,
								av_name => &param_name&,
								ai_maxdepth => &param_maxdepth&);
end;
```
In the code replace the `&param_...&` variables with your desired input.
while the other parameters are obvious the ai_MaxDepth parameter is the
nested dependencies level parameter, you can try 1, 2, 3, 4, ... values
and you will get the results. Be careful it can take a while for the big
number for the ai_MaxDepth parameter.
