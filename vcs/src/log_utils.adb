-----------------------------------------------------------------------
--                          G L I D E  I I                           --
--                                                                   --
--                        Copyright (C) 2002                         --
--                            ACT-Europe                             --
--                                                                   --
-- GLIDE is free software; you can redistribute it and/or modify  it --
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

with GNAT.OS_Lib;               use GNAT.OS_Lib;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;

with Basic_Mapper;              use Basic_Mapper;
with OS_Utils;                  use OS_Utils;

package body Log_Utils is

   --  The format for the mappings file is as follows :
   --
   --      File_1
   --      Log_1
   --      File_2
   --      Log_2
   --      File_3
   --      Log_3
   --
   --  and so on.

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Kernel : access Kernel_Handle_Record'Class) is
      Logs_Dir : String
        := Format_Pathname (Get_Home_Dir (Kernel) & "/log_files");
      Mapper   : File_Mapper_Access;
   begin
      if not Is_Directory (Logs_Dir) then
         Make_Dir (Logs_Dir);
      end if;

      if Is_Regular_File (Format_Pathname (Logs_Dir & "/mapping")) then
         Load_Mapper (Mapper, Format_Pathname (Logs_Dir & "/mapping"));
         Set_Logs_Mapper (Kernel, Mapper);
      end if;
   end Initialize;

   -----------------------
   -- Get_Log_From_File --
   -----------------------

   function Get_Log_From_File
     (Kernel    : access Kernel_Handle_Record'Class;
      File_Name : String) return String
   is
      Mapper      : File_Mapper_Access := Get_Logs_Mapper (Kernel);
      Return_Name : String := Get_Other_File (Mapper, File_Name);
   begin
      --  ??? Right now, we save the mapping every time that we add
      --  an entry. This is a bit inefficient, we should save the mapping
      --  on disk only on exit.

      if Return_Name = "" then
         declare
            Logs_Dir : String
              := Format_Pathname (Get_Home_Dir (Kernel) & "/log_files");
            File     : File_Descriptor;
            S : String := Logs_Dir
              & Directory_Separator
              & Base_Name (File_Name)
              & "_log";
         begin
            if not Is_Regular_File
              (Logs_Dir & Directory_Separator & Base_Name (File_Name) & "_log")
            then
               File := Create_New_File (S, Text);
               Close (File);
               Add_Entry (Mapper, File_Name, S);
               Save_Mapper
                 (Mapper, Format_Pathname (Logs_Dir & "/mapping"));
               return S;

            else
               for J in Natural'Range loop
                  declare
                     Im : String := Integer'Image (J);
                     S  : String := Logs_Dir
                       & Directory_Separator
                       & Base_Name (File_Name)
                       & "_"
                       & Im (Im'First + 1 .. Im'Last)
                       & "_log";
                  begin
                     if not Is_Regular_File (S) then
                        File := Create_New_File (S, Text);
                        Close (File);
                        Add_Entry (Mapper, File_Name, S);
                        Save_Mapper
                          (Mapper, Format_Pathname (Logs_Dir & "/mapping"));
                        return S;
                     end if;
                  end;
               end loop;

               return "";
            end if;
         end;
      else
         return Return_Name;
      end if;
   end Get_Log_From_File;

   -----------------------
   -- Get_File_From_Log --
   -----------------------

   function Get_File_From_Log
     (Kernel   : access Kernel_Handle_Record'Class;
      Log_Name : String) return String
   is
      Mapper : File_Mapper_Access := Get_Logs_Mapper (Kernel);
   begin
      return Get_Other_File (Mapper, Log_Name);
   end Get_File_From_Log;

   -------------
   -- Get_Log --
   -------------

   function Get_Log
     (Kernel    : access Kernel_Handle_Record'Class;
      File_Name : String) return String
   is
      R : String_Access;
   begin
      R := Read_File (Get_Log_From_File (Kernel, File_Name));

      if R = null then
         return "";

      else
         declare
            S : String := R.all;
         begin
            Free (R);
            return S;
         end;
      end if;
   end Get_Log;

end Log_Utils;
