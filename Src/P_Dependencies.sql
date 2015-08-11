create or replace package P_Dependencies is

   -- Author  : DAVIT
   -- Created : 10/08/15 17:33:27
   -- Purpose :

   function L_GetPart(av_source varchar2, av_separator varchar2,
                      ai_nth pls_integer) return varchar2;

   procedure PrintDependencies(av_Schema varchar2 := user, av_Type varchar2,
                               av_Name varchar2, ai_MaxDepth int := 1);

end P_Dependencies;
/
create or replace package body P_Dependencies is

   -- Symbols
   cv_Sep constant varchar2(2) := '->';

   -- Dependencies source cursor and table type declarations
   cursor cur_ref(av_Schema varchar2, av_Type varchar2, av_Name varchar2) is
      select distinct replace(TVal, ' BODY') TRoot, referenced_owner,
                      replace(referenced_type, ' BODY') referenced_type,
                      referenced_name,
                      case
                         when referenced_type in ('TABLE', 'VIEW') then
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
                       'TRIGGER', 'TYPE', 'TYPE BODY', 'TABLE', 'VIEW')
                  and d.referenced_owner = user)
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
         dbms_output.put_line('Level = ' || R.lvl || '; Root = ' ||
                              ltrim(R.Tree, cv_Sep));
      end loop;
   end;

   -- Procedure to PrintArray
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
   end;

   procedure PrintDependencies(av_Schema varchar2, av_Type varchar2,
                               av_Name varchar2, ai_MaxDepth int := 1) is
   
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
                                                    Src(li).TRoot);
            else
               T_Dep(Src(li).Referenced_owner, Src(li).Referenced_type,
                     Src(li).Referenced_name, lv_ParentKey, Idx(lv_ParentKey));
            end if;
         end loop;
      end;
   
   begin
      T_Dep(av_Schema, av_Type, av_Name, '', li_Depth);
      printSorted(Tree);
   end;

end P_Dependencies;
/
