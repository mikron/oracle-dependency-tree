# DependenciesTree
After compiling the package you can use the code bellow to call the
procedure "
begin
-- Call the procedure
p_Dependencies.printDependencies(av_schema => ¶m_schema&,
av_type => ¶m_type&,
av_name => ¶m_name&,
ai_maxdepth => ¶m_maxdepth&);
end;
". In the code replace the ¶m_...& variables with your desited input.
while the other parameters are obvious the ai_MaxDepth parameter is the
nested dependencies level parameter, you can try 1, 2, 3, 4, ... values
and you will get the results. Be careful it can take a while for the big
number for the ai_MaxDepth parameter.
