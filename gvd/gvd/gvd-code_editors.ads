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

--  This package implements a text area target to the display of source
--  code.
--  It knows how to highligh keywords, strings and commands, and how
--  to display icons at the beginning of each line where a given function
--  returns True.
--  It also provides a source explorer that can quickly display and jump
--  in the various entities in the file (e.g procedures, types, ...).
--
--  Caches
--  =======
--
--  Some data is expensive to recompute for each file (e.g the list of lines
--  that contain code). We have thus implemented a system of caches so that
--  we don't need to recompute this data every time the file is reloaded.
--  This information is also computed in a lazy fashion, ie while nothing
--  else is happening in the application.

with Glib;
with Gdk.Bitmap;
with Gdk.Color;
with Gdk.Font;
with Gdk.Pixmap;
with Gtk.Box;
with Gtk.Layout;
with Gtk.Main;
with Gtk.Pixmap;
with Gtk.Scrolled_Window;
with Gtk.Text;
with Gtk.Widget;
with Gtkada.Types;
with Language;
with Odd.Types;
with Odd.Explorer;

package Odd.Code_Editors is

   type Code_Editor_Record is new Gtk.Box.Gtk_Box_Record with private;
   type Code_Editor is access all Code_Editor_Record'Class;

   procedure Gtk_New_Hbox
     (Editor      : out Code_Editor;
      Process     : access Gtk.Widget.Gtk_Widget_Record'Class;
      Homogeneous : Boolean := False;
      Spacing     : Glib.Gint := 0);
   --  Create a new editor window.
   --  The name and the parameters are chosen so that this type is compatible
   --  with the code generated by Gate for a Gtk_Box.

   procedure Initialize
     (Editor      : access Code_Editor_Record'Class;
      Process     : access Gtk.Widget.Gtk_Widget_Record'Class;
      Homogeneous : Boolean := False;
      Spacing     : Glib.Gint := 0);
   --  Internal procedure.

   procedure Configure
     (Editor            : access Code_Editor_Record;
      Ps_Font_Name      : String;
      Font_Size         : Glib.Gint;
      Default_Icon      : Gtkada.Types.Chars_Ptr_Array;
      Current_Line_Icon : Gtkada.Types.Chars_Ptr_Array;
      Stop_Icon         : Gtkada.Types.Chars_Ptr_Array;
      Comments_Color    : String;
      Strings_Color     : String;
      Keywords_Color    : String);
   --  Set the various settings of an editor.
   --  Ps_Font_Name is the name of the postscript font that will be used to
   --  display the text. It should be a fixed-width font, which is nice for
   --  source code.
   --  Default_Icon is used for the icon that can be displayed on the left of
   --  each line.
   --  Current_Line_Icon is displayed on the left of the line currently
   --  "active" (using the procedure Set_Line below).
   --
   --  The editor will automatically free its allocated memory when it is
   --  destroyed.

   procedure Set_Show_Line_Nums (Editor : access Code_Editor_Record;
                                 Show   : Boolean := False);
   --  Indicate whether line numbers should be displayed or not.

   function Get_Show_Line_Nums (Editor : access Code_Editor_Record)
                               return Boolean;
   --  Return the state of line numbers in the editor

   procedure Set_Show_Lines_With_Code (Editor : access Code_Editor_Record;
                                       Show   : Boolean);
   function Get_Show_Lines_With_Code (Editor : access Code_Editor_Record)
                                     return Boolean;
   --  Indicate whether lines where a user can set a breakpoint have a small
   --  dot displayed on the side.

   function Get_Current_File (Editor : access Code_Editor_Record)
                             return String;
   --  Return the name of the currently edited file.
   --  "" is returned if there is no current file.

   procedure Set_Current_Language
     (Editor : access Code_Editor_Record;
      Lang   : Language.Language_Access);
   --  Change the current language for the editor.
   --  The text already present in the editor is not re-highlighted for the
   --  new language, this only influences future addition to the editor.
   --
   --  If Lang is null, then no color highlighting will be performed.

   procedure Clear (Editor : access Code_Editor_Record);
   --  Clear the contents of the editor.

   procedure Load_File
     (Editor      : access Code_Editor_Record;
      File_Name   : String;
      Set_Current : Boolean := True);
   --  Load and append a file in the editor.
   --  The contents is highlighted based on the current language.
   --  Debugger is used to calculate which lines should get icons on the side,
   --  through calls to Line_Contains_Code.
   --  If Set_Current is True, then File_Name becomes the current file for the
   --  debugger (ie the one that contains the current execution line).

   procedure File_Not_Found
     (Editor    : access Code_Editor_Record;
      File_Name : String);
   --  Report a file not found.
   --  This delete the currently displayed file, and display a warning message.

   procedure Set_Line
     (Editor      : access Code_Editor_Record;
      Line        : Natural;
      Set_Current : Boolean := True);
   --  Set the current line (and draw the button on the side).
   --  If Set_Current is True, then the line becomes the current line (ie the
   --  one on which the debugger is stopped). Otherwise, Line is simply the
   --  line that we want to display in the editor.

   function Get_Line (Editor : access Code_Editor_Record) return Natural;
   --  Return the current line.

   procedure Update_Breakpoints
     (Editor    : access Code_Editor_Record;
      Br        : Odd.Types.Breakpoint_Array);
   --  Change the list of breakpoints to highlight in the editor.
   --  All the breakpoints that previously existed are removed from the screen,
   --  and replaced by the new ones.
   --  The breakpoints that do not apply to the current file are ignored.

   procedure Highlight_Word
     (Editor   : access Code_Editor_Record;
      Position : Odd.Explorer.Position_Type);
   --  Highlight the word that starts at the given position in the file
   --  associated with the editor (ie ignoring the line numbers that could
   --  be displayed).

   function Get_Process (Editor : access Code_Editor_Record'Class)
                        return Gtk.Widget.Gtk_Widget;
   --  Return the process tab in which the editor is inserted.

private

   type Color_Array is array (Language.Language_Entity'Range) of
     Gdk.Color.Gdk_Color;

   type String_Access is access String;

   type Code_Editor_Record is new Gtk.Box.Gtk_Box_Record with record
      Text    : Gtk.Text.Gtk_Text;
      Buttons : Gtk.Layout.Gtk_Layout;

      Process : Gtk.Widget.Gtk_Widget;
      --  The process tab in which the editor is found.

      Explorer        : Odd.Explorer.Explorer_Access;
      Explorer_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;

      Current_File : String_Access;
      Buffer       : String_Access;

      Lang           : Language.Language_Access;
      Font           : Gdk.Font.Gdk_Font;
      Default_Pixmap : Gdk.Pixmap.Gdk_Pixmap := Gdk.Pixmap.Null_Pixmap;
      Default_Mask   : Gdk.Bitmap.Gdk_Bitmap := Gdk.Bitmap.Null_Bitmap;
      Stop_Pixmap    : Gdk.Pixmap.Gdk_Pixmap := Gdk.Pixmap.Null_Pixmap;
      Stop_Mask      : Gdk.Bitmap.Gdk_Bitmap := Gdk.Bitmap.Null_Bitmap;
      Colors         : Color_Array := (others => Gdk.Color.Null_Color);

      Current_Line_Button : Gtk.Pixmap.Gtk_Pixmap;
      Current_Line        : Natural := 0;
      Show_Line_Nums      : Boolean := False;

      Show_Lines_With_Code : Boolean := True;
      --  Whether the lines where one can set a breakpoint have a small dot
      --  on the side.

      Breakpoint_Buttons : Gtk.Widget.Widget_List.Glist;
      --  The pixmaps for each of the breakpoints

      Idle_Id : Gtk.Main.Idle_Handler_Id := 0;
      --  Id for the Idle handle that is used to recompute the lines that
      --  contain some code.

      Line_Height : Gint;
      --  Height in pixel of a single line in the editor

      Current_File_Cache : Odd.Types.File_Cache_Access;
      --  Cached data for the file currently displayed

   end record;

end Odd.Code_Editors;
