-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Tags; use Ada.Tags;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Odd.Strings;    use Odd.Strings;

package body Debugger.Gdb.Ada is

   use Language;

   procedure Parse_Array_Type
     (Lang      : access Gdb_Ada_Language;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Result    : out Generic_Type_Access);
   --  Parse the description of an array type.
   --  Index should point at the opening character of the array in Type_Str
   --  (ie "array " in gdb).

   procedure Parse_Record_Type
     (Lang      : access Gdb_Ada_Language;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Result    : out Generic_Type_Access;
      End_On    : String);
   --  Parse the type describing a record.
   --  Index should pointer after the initial "record ", and the record is
   --  assumed to end on a string like End_On.
   --  This function is also used to parse the variant part of a record.

   procedure Parse_Array_Value
     (Lang     : access Gdb_Ada_Language;
      Type_Str : String;
      Index    : in out Natural;
      Result   : in out Array_Type_Access);
   --  Parse the value of an array.

   ----------------
   -- Parse_Type --
   ----------------

   procedure Parse_Type
     (Lang     : access Gdb_Ada_Language;
      Type_Str : String;
      Entity   : String;
      Index    : in out Natural;
      Result   : out Generic_Type_Access) is
   begin
      case Type_Str (Index) is
         when '<' =>

            --  A union type

            if Looking_At (Type_Str, Index, "<union ") then
               Index := Index + 7;
               Skip_To_Char (Type_Str, Index, '{');
               Index := Index + 1;
               Parse_Record_Type (Lang, Type_Str, Entity, Index, Result, "}>");

            --  A reference (for "in out" parameters)
            --  ??? Simply ignore that fact, and parse the type...

            elsif Looking_At (Type_Str, Index, "<ref>") then

               Index := Index + 6;
               Parse_Type (Lang, Type_Str, Entity, Index, Result);

            --  Simple types, like <4-byte integer> and <4-byte float>

            else
               Skip_To_Char (Type_Str, Index, '>');
               Index := Index + 1;
               Result := New_Simple_Type;

            end if;

         when 'a' =>

            --  Arrays, as in "array (1 .. 4, 3 .. 5) of character"

            if Looking_At (Type_Str, Index, "array ") then
               Parse_Array_Type (Lang, Type_Str, Entity, Index, Result);

            --  Access types

            elsif Looking_At (Type_Str, Index, "access ") then
               Result := New_Access_Type;
            else
               raise Unexpected_Type;
            end if;

         when 'm' =>

            --  Modular types

            if Looking_At (Type_Str, Index, "mod ") then
               declare
                  Modulo : Long_Integer;
               begin
                  Index := Index + 4;
                  Parse_Num (Type_Str, Index, Modulo);
                  Result := New_Mod_Type (Modulo);
               end;
            else
               raise Unexpected_Type;
            end if;

         when 'n' =>

            --  A tagged record type, as in
            --  new tagged_type with record c : float; end record;

            if Looking_At (Type_Str, Index, "new ") then
               declare
                  Child  : Generic_Type_Access;
                  Parent : Generic_Type_Access;
                  Last   : Natural;
               begin
                  Index := Index + 4;
                  Result := New_Class_Type (Num_Ancestors => 1);

                  --  What is the ancestor ?

                  Last := Index;
                  while Type_Str (Last) /= ' ' loop
                     Last := Last + 1;
                  end loop;

                  declare
                     Ancestor_Type : String :=
                       Type_Of (Get_Debugger (Lang),
                                Type_Str (Index .. Last - 1));
                     Tmp : Natural := Ancestor_Type'First;
                  begin
                     Parse_Type (Lang, Ancestor_Type,
                                 Type_Str (Index .. Last - 1),
                                 Tmp, Parent);
                  end;
                  Add_Ancestor (Class_Type (Result.all), 1,
                                Class_Type_Access (Parent));

                  --  Get the child (skip "with record")

                  Index := Last + 12;
                  Parse_Record_Type (Lang, Type_Str, Entity, Index, Child,
                                     "end record");
                  Set_Child (Class_Type (Result.all),
                             Record_Type_Access (Child));
               end;
            else
               raise Unexpected_Type;
            end if;

         when 'r' =>

            --  A record type, as in 'record field1: integer; end record'

            if Looking_At (Type_Str, Index, "record") then
               Index := Index + 7;
               Parse_Record_Type
                 (Lang, Type_Str, Entity, Index, Result, "end record");

            --  Range types

            elsif Looking_At (Type_Str, Index, "range ") then
               declare
                  Min, Max : Long_Integer;
               begin
                  Index := Index + 6;
                  Parse_Num (Type_Str, Index, Min);
                  Index := Index + 4; --  skips ' .. '
                  Parse_Num (Type_Str, Index, Max);
                  Result := New_Range_Type (Min, Max);
               end;

            else
               raise Unexpected_Type;
            end if;

         when 't' =>

            --  A tagged type

            if Looking_At (Type_Str, Index, "tagged record") then
               Index := Index + 14;
               declare
                  Child : Generic_Type_Access;
               begin
                  Parse_Record_Type (Lang, Type_Str, Entity, Index, Child,
                                     "end record");
                  Result := New_Class_Type (Num_Ancestors => 0);
                  Set_Child (Class_Type (Result.all),
                             Record_Type_Access (Child));
               end;
            else
               raise Unexpected_Type;
            end if;

         when '(' =>

            --  Enumeration type
            Skip_To_Char (Type_Str, Index, ')');
            Index := Index + 1;
            Result := New_Enum_Type;

         --  A type we do not expect.

         when others =>
            raise Unexpected_Type;
      end case;
   end Parse_Type;

   -----------------
   -- Parse_Value --
   -----------------

   procedure Parse_Value
     (Lang       : access Gdb_Ada_Language;
      Type_Str   : String;
      Index      : in out Natural;
      Result     : in out Generic_Values.Generic_Type_Access;
      Repeat_Num : out Positive)
   is
   begin
      Repeat_Num := 1;

      -------------------
      -- Simple values --
      -------------------

      if Result'Tag = Simple_Type'Tag
        or else Result'Tag = Range_Type'Tag
        or else Result'Tag = Mod_Type'Tag
        or else Result'Tag = Enum_Type'Tag
      then
         if Type_Str /= "" then
            declare
               Int : constant Natural := Index;
            begin
               Skip_Simple_Value (Type_Str, Index);
               Set_Value (Simple_Type (Result.all),
                          Type_Str (Int .. Index - 1));

               -------------------
               -- Repeat values --
               -------------------
               --  This only happens inside arrays, so we can simply replace
               --  Result (it will be deleted the next time the item is
               --  parsed anyway).

               if Looking_At (Type_Str, Index, "<repeats ") then
                  Index := Index + 9;
                  Parse_Num (Type_Str,
                             Index,
                             Long_Integer (Repeat_Num));
                  Index := Index + 7;  --  skips " times>"
               end if;

            end;
         else
            Set_Value (Simple_Type (Result.all), "<???>");
         end if;

      -------------------
      -- Access values --
      -------------------
      --  The value looks like:   (access integer) 0xbffff54c
      --  or                  :    0x0

      elsif Result'Tag = Access_Type'Tag then

         --  Skip the parenthesis contents if needed
         if Type_Str (Index) = '(' then
            Skip_To_Char (Type_Str, Index, ')');
            Index := Index + 2;
         end if;

         declare
            Int : constant Natural := Index;
         begin
            Skip_Hexa_Digit (Type_Str, Index);
            Set_Value (Simple_Type (Result.all), Type_Str (Int .. Index - 1));
         end;

      -------------------
      -- String values --
      -------------------

      elsif Result'Tag = Array_Type'Tag
        and then Num_Dimensions (Array_Type (Result.all)) = 1
        and then Type_Str'Length /= 0
        and then Type_Str (Index) = '"'
      then
         declare
            Dim : Dimension := Get_Dimensions (Array_Type (Result.all), 1);
            S : String (1 .. Integer (Dim.Last - Dim.First + 1));
            Simple : Simple_Type_Access;

         begin
            Parse_Cst_String (Type_Str, Index, S);
            Simple := Simple_Type_Access (New_Simple_Type);
            Set_Value (Simple.all, S);
            Set_Value (Item       => Array_Type (Result.all),
                       Elem_Value => Simple,
                       Elem_Index => 0);
            Shrink_Values (Array_Type (Result.all));
         end;

      ------------------
      -- Array values --
      ------------------

      elsif Result'Tag = Array_Type'Tag
        and then Type_Str'Length /= 0   --  for empty Arrays
      then
         Parse_Array_Value (Lang, Type_Str, Index, Array_Type_Access (Result));

      -------------------
      -- Record values --
      -------------------

      elsif Result'Tag = Record_Type'Tag then
         declare
            R : Record_Type_Access := Record_Type_Access (Result);
            Int : Natural;
         begin

            --  Skip initial '(' if we are still looking at it (we might not
            --  if we are parsing a variant part)
            if Index <= Type_Str'Last and then Type_Str (Index) = '(' then
               Index := Index + 1;
            end if;

            for J in 1 .. Num_Fields (R.all) loop

               --  If we are expecting a field

               if Get_Variant_Parts (R.all, J) = 0 then
                  declare
                     V          : Generic_Type_Access := Get_Value (R.all, J);
                     Repeat_Num : Positive;
                  begin
                     --  Skips '=>'
                     --  This also skips the address part in some "in out"
                     --  parameters, like:
                     --    (<ref> gnat.expect.process_descriptor) @0x818a990: (
                     --     pid => 2012, ...

                     Skip_To_Char (Type_Str, Index, '=');
                     Index := Index + 3;
                     Parse_Value (Lang, Type_Str, Index, V, Repeat_Num);
                  end;

               --  Else we have a variant part record

               else

                  if Type_Str (Index) = ',' then
                     Index := Index + 1;
                     Skip_Blanks (Type_Str, Index);
                  end if;

                  --  Find which part is active
                  --  We simply get the next field name and search for the
                  --  part that defines it
                  Int := Index;
                  Skip_To_Char (Type_Str, Int, ' ');

                  declare
                     Repeat_Num : Positive;
                     V : Generic_Type_Access;
                  begin
                     V := Find_Variant_Part
                       (Item     => R.all,
                        Field    => J,
                        Contains => Type_Str (Index .. Int - 1));

                     Parse_Value (Lang, Type_Str, Index, V, Repeat_Num);
                  end;
               end if;
            end loop;
         end;

         Skip_Blanks (Type_Str, Index);

         --  Skip closing ')', if seen
         if Index <= Type_Str'Last and then Type_Str (Index) = ')' then
            Index := Index + 1;
         end if;

      ------------------
      -- Class values --
      ------------------

      elsif Result'Tag = Class_Type'Tag then
         declare
            R : Generic_Type_Access;
         begin
            for A in 1 .. Get_Num_Ancestors (Class_Type (Result.all)) loop
               R := Get_Ancestor (Class_Type (Result.all), A);
               Parse_Value (Lang, Type_Str, Index, R, Repeat_Num);
            end loop;
            R := Get_Child (Class_Type (Result.all));
            Parse_Value (Lang, Type_Str, Index, R, Repeat_Num);
         end;
      end if;
   end Parse_Value;

   ----------------------
   -- Parse_Array_Type --
   ----------------------

   procedure Parse_Array_Type
     (Lang      : access Gdb_Ada_Language;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Result    : out Generic_Type_Access)
   is
      Item_Separator : constant Character := ',';
      Dimension_End  : constant Character := ')';
      Num_Dim   : Integer := 1;
      Tmp_Index : Natural := Index;
      R         : Array_Type_Access;
      Index_Str : Unbounded_String;

   begin
      --  As a special case, if we have (<>) for the dimensions (ie an
      --  unconstrained array), this is treated as an access type and not an
      --  array type).

      if Looking_At (Type_Str, Tmp_Index, "array (<>)") then
         Result := New_Access_Type;
         return;
      end if;

      --  First, find the number of dimensions

      while Tmp_Index <= Type_Str'Last
        and then Type_Str (Tmp_Index) /= Dimension_End
      loop
         if Type_Str (Tmp_Index) = Item_Separator then
            Num_Dim := Num_Dim + 1;
         end if;

         Tmp_Index := Tmp_Index + 1;
      end loop;

      --  Create the type

      Result := New_Array_Type (Num_Dimensions => Num_Dim);
      R := Array_Type_Access (Result);

      --  Then parse the dimensions.

      Num_Dim := 1;
      Index := Index + 7;

      while Num_Dim <= Num_Dimensions (R.all) loop
         declare
            First, Last : Long_Integer;
         begin
            Parse_Num (Type_Str, Index, First);
            Index := Index + 4;  --  skips ' .. '
            Parse_Num (Type_Str, Index, Last);
            Index := Index + 2;  --  skips ', ' or ') '
            Set_Dimensions (R.all, Num_Dim, (First, Last));
            Num_Dim := Num_Dim + 1;
         end;
      end loop;

      --  Skip the type of the items

      Index := Index + 3; --  skips 'of '
      Tmp_Index := Index;
      Skip_To_Char (Type_Str, Index, ' ');

      --  If we have a simple type, no need to ask gdb, for efficiency reasons.

      if Is_Simple_Type (Lang, Type_Str (Tmp_Index .. Index - 1)) then
         Set_Item_Type (R.all, New_Simple_Type);

      else

         --  Get the type of the items.
         --  Note that we can not simply do a "ptype" on the string we read
         --  after "of ", since we might not be in the right context, for
         --  instance if Entity is something like "Foo::entity".
         --  Thus, we have to do a "ptype" directly on the first item of the
         --  array.

         for J in 1 .. Num_Dimensions (R.all) loop
            Append (Index_Str,
                    Long_Integer'Image (Get_Dimensions (R.all, J).First));
            if J /= Num_Dimensions (R.all) then
               Append (Index_Str, ",");
            end if;
         end loop;

         Set_Item_Type
           (R.all, Parse_Type (Get_Debugger (Lang),
                               Entity & "(" & To_String (Index_Str) & ")"));
      end if;
   end Parse_Array_Type;

   -----------------------
   -- Parse_Record_Type --
   -----------------------

   procedure Parse_Record_Type
     (Lang      : access Gdb_Ada_Language;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Result    : out Generic_Type_Access;
      End_On    : String)
   is
      Tmp_Index : Natural;
      Fields : Natural := 0;
      R : Record_Type_Access;
      Num_Parts  : Natural := 0;
   begin
      Skip_Blanks (Type_Str, Index);
      Tmp_Index := Index;

      --  Count the number of fields

      while not Looking_At (Type_Str, Tmp_Index, End_On) loop

         --  A null field ? Do no increment the count
         if Looking_At (Type_Str, Tmp_Index, "null;") then
            Tmp_Index := Tmp_Index + 5;

         --  A record with a variant part ? This counts as
         --  only one field

         elsif Looking_At (Type_Str, Tmp_Index, "case ") then
            Tmp_Index := Tmp_Index + 5;
            Skip_To_String (Type_Str, Tmp_Index, "end case;");
            Fields := Fields + 1;
            Tmp_Index := Tmp_Index + 9;

         --  Else a standard field

         else
            Skip_To_Char (Type_Str, Tmp_Index, ';');
            Tmp_Index := Tmp_Index + 1;
            Fields := Fields + 1;
         end if;

         Skip_Blanks (Type_Str, Tmp_Index);
      end loop;

      Result := New_Record_Type (Fields);
      R := Record_Type_Access (Result);

      --  Now parse all the fields

      Fields := 1;

      while Fields <= Num_Fields (R.all) loop

         if Looking_At (Type_Str, Index, "null;") then
            Index := Index + 5;

         elsif Looking_At (Type_Str, Index, "case ") then
            Index := Index + 5;
            Tmp_Index := Index;

            Skip_To_Char (Type_Str, Index, ' ');

            --  Count the number of alternatives in the variant part.

            Tmp_Index := Index;
            while not Looking_At (Type_Str, Tmp_Index, "end case") loop
               if Type_Str (Tmp_Index .. Tmp_Index + 1) = "=>" then
                  Num_Parts := Num_Parts + 1;
               end if;

               Tmp_Index := Tmp_Index + 1;
            end loop;

            Set_Field_Name (R.all, Fields, Type_Str (Tmp_Index .. Index - 1),
                            Variant_Parts => Num_Parts);

            --  Parses the parts, and create a record for each

            Num_Parts := 0;
            while not Looking_At (Type_Str, Index, "end ") loop
               Skip_To_String (Type_Str, Index, "=>");

               Index := Index + 2;
               Num_Parts := Num_Parts + 1;

               declare
                  Part : Generic_Type_Access;
               begin
                  if Num_Parts = Get_Variant_Parts (R.all, Fields) then
                     Parse_Record_Type (Lang, Type_Str, Entity,
                                        Index, Part, "end case");
                  else
                     Parse_Record_Type (Lang, Type_Str, Entity,
                                        Index, Part, "when ");
                  end if;

                  Set_Variant_Field (R.all, Fields, Num_Parts,
                                     Record_Type_Access (Part));
               end;

               Skip_Blanks (Type_Str, Index);
            end loop;

            Index := Index + 9;
            Fields := Fields + 1;

         --  Else a standard field

         else

            --  Get the name of the field

            Tmp_Index := Index;
            Skip_To_Char (Type_Str, Index, ':');
            Set_Field_Name (R.all, Fields, Type_Str (Tmp_Index .. Index - 1),
                            Variant_Parts => 0);

            --  Get the type of the field
            Index := Index + 2;
            Tmp_Index := Index;
            Skip_To_Char (Type_Str, Index, ';');

            --  If we have a simple type, no need to ask gdb, for efficiency
            --  reasons.

            if Is_Simple_Type (Lang, Type_Str (Tmp_Index .. Index - 1)) then
               Set_Value (Item  => R.all,
                          Value => New_Simple_Type,
                          Field => Fields);

            elsif Tmp_Index + 6 <= Type_Str'Last
              and then Type_Str (Tmp_Index .. Tmp_Index + 6) = "access "
            then
               Set_Value (Item  => R.all,
                          Value => New_Access_Type,
                          Field => Fields);

            else
               Set_Value (R.all,
                          Parse_Type (Get_Debugger (Lang),
                                      Entity & "."
                                      & Get_Field_Name (R.all, Fields).all),
                          Field => Fields);
            end if;

            Index := Index + 1;
            Fields := Fields + 1;
         end if;

         Skip_Blanks (Type_Str, Index);
      end loop;
   end Parse_Record_Type;

   -----------------------
   -- Parse_Array_Value --
   -----------------------

   procedure Parse_Array_Value
     (Lang     : access Gdb_Ada_Language;
      Type_Str : String;
      Index    : in out Natural;
      Result   : in out Array_Type_Access)
   is
      Dim     : Natural := 0;            --  current dimension
      Current_Index : Long_Integer := 0; --  Current index in the parsed array

      procedure Parse_Item;
      --  Parse the value of a single item, and add it to the contents of
      --  Result.

      ----------------
      -- Parse_Item --
      ----------------

      procedure Parse_Item is
         Int        : Natural := Index;
         Tmp        : Generic_Type_Access;
         Repeat_Num : Integer;
      begin
         --  Does gdb indicate the number of the item (as in '24 =>')
         --  We search the first character that does not belong to the item
         --  value.

         while Int <= Type_Str'Last
           and then Type_Str (Int) /= ','  --  item separator
           and then Type_Str (Int) /= ')'  --  end of sub-array
           and then Type_Str (Int) /= '('  --  start of sub-array
           and then Type_Str (Int) /= '='  --  index of the item
         loop
            Int := Int + 1;
         end loop;

         if Type_Str (Int) = '=' then
            Index := Int + 3;  --  skip "field_name => ";

            --  If we are not parsing the most internal dimension, we in fact
            --  saw the start of a new dimension, as in:
            --    (3 => ((6 => 1, 2), (6 => 1, 2)), ((6 => 1, 2), (6 => 1, 2)))
            --  for   array (3 .. 4, 1 .. 2, 6 .. 7) of integer
            --  In that case, don't try to parse the item

            if Dim /= Num_Dimensions (Result.all) then
               return;
            end if;

         end if;

         --  Parse the next item
         Tmp := Clone (Get_Item_Type (Result.all).all);
         Parse_Value (Lang, Type_Str, Index, Tmp, Repeat_Num);
         Set_Value (Item       => Result.all,
                    Elem_Value => Tmp,
                    Elem_Index => Current_Index,
                    Repeat_Num => Repeat_Num);
         Current_Index := Current_Index + Long_Integer (Repeat_Num);
      end Parse_Item;

   begin
      loop
         case Type_Str (Index) is
            when ')' =>
               Dim := Dim - 1;
               Index := Index + 1;

            when '(' =>
               --  A parenthesis is either the start of a sub-array (for
               --  other dimensions, or one of the items in case it is a
               --  record or an array. The distinction can be made by
               --  looking at the current dimension being parsed.

               if Dim = Num_Dimensions (Result.all) then
                  Parse_Item;
               else
                  Dim := Dim + 1;
                  Index := Index + 1;
               end if;

            when ',' | ' ' =>
               Index := Index + 1;

            when others =>
               Parse_Item;
         end case;
         exit when Dim = 0;
      end loop;

      --  Shrink the table of values.
      Shrink_Values (Result.all);
   end Parse_Array_Value;

end Debugger.Gdb.Ada;
