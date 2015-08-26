create or replace package P_Dependencies is

   -- Author  : DAVIT
   -- Created : 10/08/15 17:33:27
   -- Purpose :

   function L_GetPart(av_source varchar2, av_separator varchar2,
                      ai_nth pls_integer) return varchar2;

   function GetDependencies(av_Schema varchar2, av_Type varchar2,
                            av_Name varchar2, ai_MaxDepth int := 1)
      return TT_Dependencies;

   procedure PrintDependencies(av_Schema varchar2 := user, av_Type varchar2,
                               av_Name varchar2, ai_MaxDepth int := 1);

   function c_GetPkgProcedureCodeStyled(av_SchemaName varchar2 := user,
                                        av_ObjName varchar2,
                                        av_ObjType varchar2 := 'PACKAGE BODY',
                                        av_SubObjName varchar2,
                                        av_SubObjType varchar2 := 'PROCEDURE')
      return clob;

   function c_GetPkgProcedureCode(av_SchemaName varchar2 := user,
                                  av_ObjName varchar2,
                                  av_ObjType varchar2 := 'PACKAGE BODY',
                                  av_SubObjName varchar2,
                                  av_SubObjType varchar2 := 'PROCEDURE')
      return clob;
      
   function GetPkgDependencies(av_SchemaName varchar2 := user,
                               av_ObjName varchar2,
                               av_ObjType varchar2 := 'PACKAGE BODY',
                               av_SubObjName varchar2,
                               av_SubObjType varchar2 := 'PROCEDURE')
      return TT_Dependencies;

   procedure PrintPkgDependencies(av_SchemaName varchar2 := user,
                                  av_ObjName varchar2,
                                  av_ObjType varchar2 := 'PACKAGE BODY',
                                  av_SubObjName varchar2,
                                  av_SubObjType varchar2 := 'PROCEDURE');

end P_Dependencies;
/
create or replace package body P_Dependencies is

   -- Symbols
   cv_Sep constant varchar2(2) := '->';
   cv_DummyPro constant varchar2(30) := 'dummyprocedurefordependencies';

   -- Dependencies source cursor and table type declarations
   cursor cur_ref(av_Schema varchar2, av_Type varchar2, av_Name varchar2) is
      select distinct replace(TVal, ' BODY') TRoot, referenced_owner,
                      replace(referenced_type, ' BODY') referenced_type,
                      referenced_name,
                      case
                         when referenced_type in ('TABLE', 'VIEW', 'SYNONYM') then
                          0
                         else
                          1
                      end OrderCol
        from (select owner, type, name, referenced_owner, referenced_type,
                      referenced_name,
                      referenced_owner || '.' || referenced_type || '.' ||
                       referenced_name TVal
                 from dba_dependencies d
                where d.owner = av_Schema
                  and replace(d.type, ' BODY') = replace(av_Type, ' BODY')
                  and name = av_Name
                  and referenced_type in
                      ('PACKAGE', 'PACKAGE BODY', 'FUNCTION', 'PROCEDURE',
                       'TRIGGER', 'TYPE', 'TYPE BODY', 'TABLE', 'VIEW', 'SYNONYM')
                  and d.referenced_owner not in ('SYS'))
       order by referenced_owner, OrderCol, referenced_type, referenced_name;

   type T_CurRef is table of cur_ref%rowtype;
   type TT_Tree is table of pls_integer index by varchar2(4000);

   -- String manipulation funciton
   function L_GetPart(av_source varchar2, av_separator varchar2,
                      ai_nth pls_integer) return varchar2 is
      li_Sep pls_integer := length(av_Separator);
      li_Begin pls_integer := 1 - li_Sep;
      li_End pls_integer;
      lv_Output varchar2(32767);
   begin
      if ai_Nth = -1 then
         li_Begin := instr(av_source, av_separator, ai_Nth);
         if li_Begin = 0 then
            return null;
         end if;
      else
         li_End := instr(av_source, av_separator, 1, ai_nth);
         if ai_Nth > 1 then
            li_Begin := instr(av_source, av_separator, 1, ai_nth - 1);
            if li_Begin = 0 then
               return null;
            end if;
         end if;
      end if;
      if li_End > 0 then
         lv_Output := substr(av_Source, li_Begin + li_Sep,
                             li_End - li_Begin - li_Sep);
      elsif length(av_Source) >= li_Begin + li_Sep then
         lv_Output := substr(av_Source, li_Begin + li_Sep,
                             length(av_Source) - li_Begin);
      end if;
      return lv_Output;
   end;

   -- procedure to sort Array
   procedure printSorted(at_Tree TT_Dependencies) is
   begin
      for R in (select * from table(at_Tree) order by 1, 2) loop
         dbms_output.put_line('Level = ' || R.lvl || '; Table = ' ||
                              rpad(R.Tables, 30, ' ') || '; Root = ' ||
                              ltrim(R.Tree, cv_Sep));
      end loop;
   end;

   /*-- Procedure to PrintArray
   procedure printTree(at_Tree TT_Tree) is
      lv_idx varchar2(4000);
   begin
      lv_idx := at_Tree.first;
      while (lv_idx is not null) loop
         if at_Tree(lv_idx) > 0 then
            dbms_output.put_line('Level = ' || at_Tree(lv_idx) || '; Root = ' ||
                                 ltrim(lv_idx, cv_Sep));
         end if;
         lv_idx := at_Tree.next(lv_idx);
      end loop;
   end;*/

   function GetDependencies(av_Schema varchar2, av_Type varchar2,
                            av_Name varchar2, ai_MaxDepth int := 1)
      return TT_Dependencies is
   
      -- Tree of dependencies
      Tree TT_Dependencies := TT_Dependencies();
      Idx TT_Tree;
      li_Depth int := 0;
   
      -- Recursive procedure to load dependencies
      procedure T_Dep(av_Schema varchar2, av_Type varchar2, av_Name varchar2,
                      av_ParentKey varchar2, ai_Depth int) is
         Src T_CurRef;
         lv_ParentKey varchar2(4000);
      begin
         if L_GetPart(av_ParentKey, cv_Sep, -1) =
            av_Schema || '.' || av_Type || '.' || av_Name then
            lv_ParentKey := av_ParentKey;
         else
            lv_ParentKey := av_ParentKey || cv_Sep || av_Schema || '.' ||
                            av_Type || '.' || av_Name;
         end if;
         if Idx.exists(lv_ParentKey) then
            return;
         else
            Idx(lv_ParentKey) := ai_Depth + 1;
         end if;
      
         if Idx(lv_ParentKey) > ai_MaxDepth then
            return;
         end if;
      
         open cur_Ref(av_Schema, av_Type, av_Name);
         fetch cur_Ref bulk collect
            into Src;
         close cur_Ref;
      
         for li in 1 .. Src.count loop
            if Src(li).Referenced_Type in ('TABLE', 'VIEW') then
               Tree.extend;
               Tree(Tree.count) := TO_Dependencies(Idx(lv_ParentKey),
                                                   lv_ParentKey || cv_Sep ||
                                                    Src(li).TRoot,
                                                   Src(li).Referenced_name);
            else
               T_Dep(Src(li).Referenced_owner, Src(li).Referenced_type,
                     Src(li).Referenced_name, lv_ParentKey, Idx(lv_ParentKey));
            end if;
         end loop;
      end;
   
   begin
      T_Dep(av_Schema, av_Type, av_Name, '', li_Depth);
      return Tree;
   end;

   procedure PrintDependencies(av_Schema varchar2, av_Type varchar2,
                               av_Name varchar2, ai_MaxDepth int := 1) is
   begin
      printSorted(GetDependencies(av_Schema, av_Type, av_Name, ai_MaxDepth));
   end;

   -- Retrieve the procedure code from the package source code
   -- This procedure works for the procedures which have declaretion like bellow
   -- procedure PROCEDURE_NAME
   -- ....
   -- end PROCEDURE_NAME
   function c_GetPkgProcedureCodeStyled(av_SchemaName varchar2 := user,
                                        av_ObjName varchar2,
                                        av_ObjType varchar2 := 'PACKAGE BODY',
                                        av_SubObjName varchar2,
                                        av_SubObjType varchar2 := 'PROCEDURE')
      return clob is
      lc clob;
   begin
      for Src in (with package_source as
                   (select Line, lower(text) Text, max(Line) over() MaxLine
                     from dba_source
                    where owner = av_SchemaName
                      and name = av_ObjName
                      and type = av_ObjType),
                  first_line as
                   (select line
                     from (select line
                             from package_source
                            where instr(Text,
                                        lower(av_SubObjType || ' ' ||
                                              av_SubObjName)) > 0
                            order by utl_match.edit_distance_similarity(text,
                                                                        lower(av_SubObjType || ' ' ||
                                                                              av_SubObjName)) desc)
                    where rownum = 1),
                  last_line as
                   (select *
                     from (select line
                             from package_source
                            where instr(Text,
                                        'end ' || lower(av_SubObjName) || ';') > 0
                            order by utl_match.edit_distance_similarity(Text,
                                                                        'end ' ||
                                                                        lower(av_SubObjName) || ';') desc)
                    where rownum = 1)
                  select Text
                    from package_source
                   where line between (select line from first_line) and
                         (select line from last_line)
                   order by line) loop
      lc := lc || Src.Text;
    end loop;
      return lc;
   end;

   -- Retrieve the procedure code from the package source code
   -- Not working for the overloaded procedures
   function c_GetPkgProcedureCode(av_SchemaName varchar2 := user,
                                  av_ObjName varchar2,
                                  av_ObjType varchar2 := 'PACKAGE BODY',
                                  av_SubObjName varchar2,
                                  av_SubObjType varchar2 := 'PROCEDURE')
      return clob is
      lc clob;
   begin
      for Src in (with package_source as
                   (select Line, lower(Text) Text, max(Line) over() MaxLine
                     from dba_source
                    where owner = av_SchemaName
                      and type = av_ObjType
                      and name = av_ObjName),
                  package_procs as
                   (select f.Procedure_Name
                     from dba_procedures f
                    where owner = av_SchemaName
                      and object_type = replace(av_ObjType, ' BODY')
                      and f.Object_Name = av_ObjName),
                  first_line as
                   (select LineNo
                     from (select line LineNo
                             from package_source
                            where instr(text,
                                        lower(av_SubObjType || ' ' ||
                                              av_SubObjName)) > 0
                            order by utl_match.edit_distance_similarity(Text,
                                                                        lower(av_SubObjType || ' ' ||
                                                                              av_SubObjName)) desc)
                    where rownum = 1),
                  last_line as
                   (select min(line) LineNo
                     from Package_Source p
                    where Line > (select LineNo from First_Line)
                      and exists
                    (select *
                             from Package_Procs
                            where (instr(p.text,
                                         'procedure ' || lower(Procedure_Name)) > 0 or
                                  instr(p.text,
                                         'function ' || lower(Procedure_Name)) > 0)))
                  select Text
                    from Package_Source
                   where Line >= (select LineNo from first_line)
                     and Line < nvl((select LineNo from last_line), MaxLine)
                   order by Line) loop
      lc := lc || Src.Text;
    end loop;
      return lc;
   end;

   procedure dropProcedure(av_ProcName varchar2) is
   begin
      for O in (select *
                  from dba_objects d
                 where d.object_name = upper(av_ProcName)) loop
         execute immediate 'drop ' || o.object_type || ' ' || o.owner || '.' ||
                           o.object_name;
      end loop;
   end;

   -- print dependencies for the procedure inside the package
   function GetPkgDependencies(av_SchemaName varchar2 := user,
                               av_ObjName varchar2,
                               av_ObjType varchar2 := 'PACKAGE BODY',
                               av_SubObjName varchar2,
                               av_SubObjType varchar2 := 'PROCEDURE')
      return TT_Dependencies is
      lc_ProCode clob;
   begin
      lc_ProCode := c_GetPkgProcedureCodeStyled(av_SchemaName, av_ObjName,
                                                av_ObjType, av_SubObjName,
                                                av_SubObjType);
      if lc_ProCode is null then
         lc_ProCode := c_GetPkgProcedureCode(av_SchemaName, av_ObjName,
                                             av_ObjType, av_SubObjName,
                                             av_SubObjType);
      end if;
      if lc_ProCode is not null then
         dropProcedure(cv_DummyPro);
         execute immediate 'create ' ||
                           replace(replace(lc_ProCode,
                                           lower(av_SubObjType || ' ' ||
                                                  av_SubObjName),
                                           av_SubObjType || ' ' || cv_DummyPro),
                                   'end ' || lower(av_SubObjName),
                                   'end ' || cv_DummyPro);
         return GetDependencies(av_SchemaName, av_SubObjType,
                                upper(cv_DummyPro), ai_MaxDepth => 1);
      end if;
      return TT_Dependencies();
   end;
   
   -- print dependencies for the procedure inside the package
   procedure PrintPkgDependencies(av_SchemaName varchar2 := user,
                                  av_ObjName varchar2,
                                  av_ObjType varchar2 := 'PACKAGE BODY',
                                  av_SubObjName varchar2,
                                  av_SubObjType varchar2 := 'PROCEDURE') is
   begin
      printSorted(GetPkgDependencies(av_SchemaName, av_ObjName, av_ObjType,
                                     av_SubObjName, av_SubObjType));
      dropProcedure(cv_DummyPro);
   end;

end P_Dependencies;
/
