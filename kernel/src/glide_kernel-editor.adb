-----------------------------------------------------------------------
--                                                                   --
--                     Copyright (C) 2001                            --
--                          ACT-Europe                               --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Glide_Main_Window; use Glide_Main_Window;
with Glide_Page; use Glide_Page;
with Gtkada.MDI; use Gtkada.MDI;
with Src_Editor_Box; use Src_Editor_Box;
with GVD.Process; use GVD.Process;

package body Glide_Kernel.Editor is

   Default_Editor_Width  : constant := 400;
   Default_Editor_Height : constant := 400;

   ----------------
   -- New_Editor --
   ----------------

   procedure New_Editor
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Top    : constant Glide_Window := Glide_Window (Kernel.Main_Window);
      MDI    : constant MDI_Window :=
        Glide_Page.Glide_Page (Get_Current_Process (Top)).Process_Mdi;
      Editor : Source_Editor_Box;
      Box    : Source_Box;
      Child  : MDI_Child;

   begin
      Gtk_New (Editor, Top.Kernel);
      Gtk_New (Box, Editor);
      Set_USize (Box, Default_Editor_Width, Default_Editor_Height);
      Attach (Editor, Box);
      Child := Put (MDI, Box);
      Show_All (Box);
      Set_Title (Child, "No Name");
   end New_Editor;

   --------------
   -- New_View --
   --------------

   procedure New_View
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Top     : constant Glide_Window := Glide_Window (Kernel.Main_Window);
      MDI     : constant MDI_Window :=
        Glide_Page.Glide_Page (Get_Current_Process (Top)).Process_Mdi;
      Editor  : Source_Editor_Box;
      Box     : Source_Box;
      Focus   : constant MDI_Child := Get_Focus_Child (MDI);
      Current : Source_Box := Source_Box (Get_Widget (Focus));
      Child   : MDI_Child;
      Title   : constant String := Get_Title (Focus);

   begin
      Create_New_View (Editor, Current.Editor);
      Gtk_New (Box, Editor);
      Attach (Editor, Box);
      Child := Put (MDI, Box);
      Set_Title (Child, Title & " <2>");
   end New_View;

   ---------------
   -- Open_File --
   ---------------

   procedure Open_File
     (Kernel : access Kernel_Handle_Record'Class;
      File   : String)
   is
      Top      : constant Glide_Window := Glide_Window (Kernel.Main_Window);
      MDI      : constant MDI_Window :=
        Glide_Page.Glide_Page (Get_Current_Process (Top)).Process_Mdi;
      Success : Boolean;
      Editor  : Source_Editor_Box;
      Box     : Source_Box;
      Child   : MDI_Child;

   begin
      if File = "" then
         return;
      end if;

      Gtk_New (Editor, Top.Kernel);
      Gtk_New (Box, Editor);
      Set_USize (Box, Default_Editor_Width, Default_Editor_Height);
      Attach (Editor, Box);
      Child := Put (MDI, Box);
      Set_Title (Child, File);
      Load_File (Editor, File, Success => Success);
   end Open_File;

   -----------
   -- Go_To --
   -----------

   procedure Go_To
     (Kernel : access Kernel_Handle_Record'Class;
      File   : String;
      Line   : Natural := 0;
      Column : Natural := 0) is
   begin
      Open_File (Kernel, File);
   end Go_To;

end Glide_Kernel.Editor;
