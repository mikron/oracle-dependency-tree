create or replace package P_Dependencies is

   -- Author  : DAVIT
   -- Created : 10/08/15 17:33:27
   -- Purpose : 

   procedure PrintDependencies(av_Schema varchar2, av_Type varchar2,
                              av_Name varchar2, ai_MaxDepth int := 1);

end P_Dependencies;
/
create or replace package body P_Dependencies is

   

   -- Dependencies source cursor and table type declarations
   cursor cur_ref(av_Schema varchar2, av_Type varchar2, av_Name varchar2) is
      select replace(TRoot, ' BODY') || '->' || replace(TVal, ' BODY') TRoot,
             referenced_owner, referenced_type, referenced_name,
             case
                when referenced_type in ('TABLE', 'VIEW') then
                 0
                else
                 1
             end OrderCol
        from (select owner, type, name, referenced_owner, referenced_type,
                      referenced_name, owner || '.' || type || '.' || name TRoot,
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
   type TT_Tree is table of int index by varchar2(4000);

   -- Procedure to PrintArray
   procedure printTree(at_Tree TT_Tree) is
      lv_idx varchar2(4000);
   begin
      lv_idx := at_Tree.first;
      while (lv_idx is not null) loop
         if at_Tree(lv_idx) > 0 then
            dbms_output.put_line('Level = ' || at_Tree(lv_idx) || '; Root = ' || ltrim(lv_idx, '->'));
         end if;
         lv_idx := at_Tree.next(lv_idx);
      end loop;
   end;

   procedure PrintDependencies(av_Schema varchar2, av_Type varchar2,
                              av_Name varchar2, ai_MaxDepth int := 1) is
   
      -- Tree of dependencies
      Tree TT_Tree;
      Idx TT_Tree;
      li_Depth int := 0;
   
      -- Recursive procedure to load dependencies
      procedure T_Dep(av_Schema varchar2, av_Type varchar2, av_Name varchar2,
                      av_ParentKey varchar2, ai_Depth int) is
         Src T_CurRef;
         lv_ParentKey varchar2(4000);
      begin
         lv_ParentKey := av_ParentKey || '->' || av_Schema || '.' || av_Type || '.' ||
                         av_Name;
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
               Tree(lv_ParentKey || '->' || Src(li).TRoot) := Idx(lv_ParentKey);
            else
               T_Dep(Src(li).Referenced_owner, Src(li).Referenced_type,
                     Src(li).Referenced_name, lv_ParentKey, Idx(lv_ParentKey));
            end if;
         end loop;
      end;
   
   begin
      T_Dep(av_Schema, av_Type, av_Name, '', li_Depth);
      printTree(Tree);
   end;

end P_Dependencies;
/
