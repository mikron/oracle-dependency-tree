# Package and procedures dependencies tree
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
In the code replace the `&param_...&` variables with your desired input. Here is 
the description of the parameters.
* `av_schema` - the schema name, default value is the schema, where the package
		is called
* `av_type` - the type of the object `PROCEDURE`,`PACKAGE BODY`,`PACKAGE`,`TYPE BODY`,
		`TRIGGER`,`MATERIALIZED	VIEW`,`FUNCTION`,`VIEW`,`JAVA CLASS`,`INDEX`,`TYPE` etc
* `av_name` - object name in upper cases.
* `ai_MaxDepth` - the nested dependencies layer count. You can try `1, 2, 3, 4, ...` values
		and you will get the results. Be careful it can take a while for the big
		number for the ai_MaxDepth parameter.
