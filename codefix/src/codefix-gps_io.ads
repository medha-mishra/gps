-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                    Copyright (C) 2003-2008, AdaCore               --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with GPS.Kernel;           use GPS.Kernel;
with GNAT.Strings;

with Generic_List;
with Ada.Unchecked_Deallocation;

with Codefix.Text_Manager;   use Codefix.Text_Manager;
with Codefix.Errors_Manager; use Codefix.Errors_Manager;
with Codefix.Formal_Errors;  use Codefix.Formal_Errors;
with GNATCOLL.VFS;

package Codefix.GPS_Io is

   type Console_Interface is new Text_Interface with private;

   type GPS_Mark is new Mark_Abstr with private;

   function Get_Id (This : GPS_Mark) return String;
   --  Returns the identificator of a mark.

   overriding
   function Get_New_Mark
     (Current_Text : Console_Interface;
      Cursor       : File_Cursor'Class) return Mark_Abstr'Class;
   --  Create a new mark at the position specified by the cursor.

   overriding
   function Get_Current_Cursor
     (Current_Text : Console_Interface;
      Mark         : Mark_Abstr'Class) return File_Cursor'Class;
   --  Return the current position of the mark.

   overriding
   procedure Free (This : in out GPS_Mark);
   --  Free the memory associated to a GPS_Mark

   overriding
   procedure Free (This : in out Console_Interface);
   --  Free the memory associated with the Console_Interface

   overriding
   procedure Undo (This : in out Console_Interface);
   --  Undo the last action made in This.

   overriding
   function Get
     (This   : Console_Interface;
      Cursor : Text_Cursor'Class;
      Len    : Natural) return String;
   --  Get Len characters from the file and the position specified by the
   --  cursor.

   overriding
   function Get
     (This   : Console_Interface;
      Cursor : Text_Cursor'Class) return Character;
   --  Get the character from the file and the position specified by the
   --  cursor.

   overriding
   function Get_Line
     (This      : Console_Interface;
      Cursor    : Text_Cursor'Class;
      Start_Col : Column_Index := 0) return String;
   --  Get all character from the column and the line specified by the cursor
   --  to the end of the line.

   overriding
   procedure Replace
     (This      : in out Console_Interface;
      Cursor    : Text_Cursor'Class;
      Len       : Natural;
      New_Value : String);
   --  Replace the Len characters, from the position designed by the cursor, by
   --  New_Value.

   overriding
   procedure Replace
     (This         : in out Console_Interface;
      Start_Cursor : Text_Cursor'Class;
      End_Cursor   : Text_Cursor'Class;
      New_Value    : String);
   --  Replace the characters between Start_Cursor and End_Cursor by New_Value.

   overriding
   procedure Add_Line
     (This     : in out Console_Interface;
      Cursor   : Text_Cursor'Class;
      New_Line : String;
      Indent   : Boolean := False);
   --  Add a line at the cursor specified. To add a line at the
   --  begining of the text, set cursor line = 0.

   overriding
   procedure Delete_Line
     (This : in out Console_Interface;
      Cursor : Text_Cursor'Class);
   --  Delete the line where the cursor is.

   overriding
   procedure Indent_Line
     (This   : in out Console_Interface;
      Cursor : Text_Cursor'Class);
   --  Indent the line pointed by the cursor.

   overriding
   procedure Initialize
     (This : in out Console_Interface;
      Path : GNATCOLL.VFS.Virtual_File);
   --  Initialize the structure of the Console_Interface. Actually do noting.

   overriding
   function Read_File (This : Console_Interface)
      return GNAT.Strings.String_Access;
   --  Get the entire file

   overriding
   function Line_Max (This : Console_Interface) return Natural;
   --  Return the last position of line in File_Interface.

   procedure Set_Kernel
     (This : in out Console_Interface; Kernel : Kernel_Handle);
   --  Set the value of the kernel linked to the Console_Interface.

   overriding
   procedure Constrain_Update (This : in out Console_Interface);
   --  Set the text to modified state.

private

   package String_List is new Generic_List (GNAT.Strings.String_Access);
   use String_List;
   --  ??? Should use standard string list

   type Ptr_Boolean is access all Boolean;
   type Ptr_String_List is access all String_List.List;
   type Ptr_Natural is access all Natural;

   procedure Free is new Ada.Unchecked_Deallocation (Boolean, Ptr_Boolean);
   procedure Free is new Ada.Unchecked_Deallocation
     (String_List.List, Ptr_String_List);
   procedure Free is new Ada.Unchecked_Deallocation (Natural, Ptr_Natural);

   type Console_Interface is new Text_Interface with record
      Lines         : Ptr_String_List := new String_List.List;
      Lines_Number  : Ptr_Natural := new Natural'(0);
      File_Modified : Ptr_Boolean := new Boolean'(True);
      Kernel        : Kernel_Handle;
   end record;

   procedure Update (This : Console_Interface);
   --  Update the values of lines contained into the console_interface if
   --  changes appened.

   function Get_Recorded_Line
     (This   : Console_Interface;
      Number : Natural) return String;
   --  Return a line that has been previously recorded into the
   --  Console_Interface.

   type GPS_Mark is new Mark_Abstr with record
      Id : GNAT.Strings.String_Access;
   end record;

end Codefix.GPS_Io;
