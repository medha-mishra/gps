-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2001-2003                       --
--                            ACT-Europe                             --
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

with Ada.Exceptions;            use Ada.Exceptions;
with Ada.Characters.Handling;   use Ada.Characters.Handling;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with GNAT.Case_Util;            use GNAT.Case_Util;
with Glib.Xml_Int;              use Glib.Xml_Int;
with Gdk.Types;                 use Gdk.Types;
with Gdk.Types.Keysyms;         use Gdk.Types.Keysyms;
with Glib;                      use Glib;
with Glib.Convert;              use Glib.Convert;
with Glib.Object;               use Glib.Object;
with Glib.Values;               use Glib.Values;
with Glide_Intl;                use Glide_Intl;
with Glide_Kernel;              use Glide_Kernel;
with Glide_Kernel.Console;      use Glide_Kernel.Console;
with Glide_Kernel.Modules;      use Glide_Kernel.Modules;
with Glide_Kernel.Preferences;  use Glide_Kernel.Preferences;
with Glide_Kernel.Project;      use Glide_Kernel.Project;
with Glide_Kernel.Timeout;      use Glide_Kernel.Timeout;
with Language;                  use Language;
with Language_Handlers;         use Language_Handlers;
with Glide_Main_Window;         use Glide_Main_Window;
with Interactive_Consoles;      use Interactive_Consoles;
with Basic_Types;               use Basic_Types;
with GVD.Status_Bar;            use GVD.Status_Bar;
with Gtk.Box;                   use Gtk.Box;
with Gtk.Button;                use Gtk.Button;
with Gtk.Combo;                 use Gtk.Combo;
with Gtk.Dialog;                use Gtk.Dialog;
with Gtk.Enums;                 use Gtk.Enums;
with Gtk.GEntry;                use Gtk.GEntry;
with Gtk.Handlers;              use Gtk.Handlers;
with Gtk.Label;                 use Gtk.Label;
with Gtk.Menu;                  use Gtk.Menu;
with Gtk.Menu_Item;             use Gtk.Menu_Item;
with Gtk.Main;                  use Gtk.Main;
with Gtk.Stock;                 use Gtk.Stock;
with Gtk.Toolbar;               use Gtk.Toolbar;
with Gtk.Widget;                use Gtk.Widget;
with Gtk.Text_Mark;             use Gtk.Text_Mark;
with Gtkada.Dialogs;            use Gtkada.Dialogs;
with Gtkada.Entry_Completion;   use Gtkada.Entry_Completion;
with Gtkada.Handlers;           use Gtkada.Handlers;
with Gtkada.MDI;                use Gtkada.MDI;
with Gtkada.File_Selector;      use Gtkada.File_Selector;
with Src_Editor_Box;            use Src_Editor_Box;
with Src_Editor_View;           use Src_Editor_View;
with String_List_Utils;         use String_List_Utils;
with String_Utils;              use String_Utils;
with File_Utils;                use File_Utils;
with Shell;                     use Shell;
with Traces;                    use Traces;
with Projects.Registry;         use Projects, Projects.Registry;
with Src_Contexts;              use Src_Contexts;
with Find_Utils;                use Find_Utils;
with Histories;                 use Histories;
with OS_Utils;                  use OS_Utils;
with Aliases_Module;            use Aliases_Module;

with Gtkada.Types;              use Gtkada.Types;
with Gdk.Pixbuf;                use Gdk.Pixbuf;

with Generic_List;
with GVD.Preferences; use GVD.Preferences;

with Src_Editor_Module.Line_Highlighting;

package body Src_Editor_Module is

   Me : constant Debug_Handle := Create ("Src_Editor_Module");

   Hist_Key : constant History_Key := "reopen_files";
   --  Key to use in the kernel histories to store the most recently opened
   --  files.

   Open_From_Path_History : constant History_Key := "open-from-project";
   --  Key used to store the most recently open files in the Open From Project
   --  dialog.

   editor_xpm : aliased Chars_Ptr_Array (0 .. 0);
   pragma Import (C, editor_xpm, "mini_page_xpm");

   procedure Generate_Body_Cb (Data : Process_Data; Status : Integer);
   --  Callback called when gnatstub has completed.

   procedure Pretty_Print_Cb (Data : Process_Data; Status : Integer);
   --  Callback called when gnatpp has completed.

   procedure Gtk_New
     (Box : out Source_Box; Editor : Source_Editor_Box);
   --  Create a new source box.

   procedure Initialize
     (Box : access Source_Box_Record'Class; Editor : Source_Editor_Box);
   --  Internal initialization function.

   function Mime_Action
     (Kernel    : access Kernel_Handle_Record'Class;
      Mime_Type : String;
      Data      : GValue_Array;
      Mode      : Mime_Mode := Read_Write) return Boolean;
   --  Process, if possible, the data sent by the kernel

   procedure Save_To_File
     (Kernel  : access Glide_Kernel.Kernel_Handle_Record'Class;
      Name    : String := "";
      Success : out Boolean);
   --  Save the current editor to Name, or its associated filename if Name is
   --  null.

   function Open_File
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : String := "";
      Create_New : Boolean := True;
      Focus      : Boolean := True) return Source_Box;
   --  Open a file and return the handle associated with it.
   --  If Add_To_MDI is set to True, the box will be added to the MDI window.
   --  If Focus is True, the box will be raised if it is in the MDI.
   --  See Create_File_Exitor.

   function Create_File_Editor
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : String;
      Create_New : Boolean := True) return Source_Editor_Box;
   --  Create a new text editor that edits File.
   --  If File is the empty string, or the file doesn't exist and Create_New is
   --  True, then an empty editor is created.
   --  No check is done to make sure that File is not already edited
   --  elsewhere. The resulting editor is not put in the MDI window.

   function Save_Function
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget;
      Force  : Boolean := False) return Save_Return_Value;
   --  Save the text editor.
   --  If Force is False, then offer a choice to the user before doing so.

   type Location_Idle_Data is record
      Edit  : Source_Editor_Box;
      Line, Column, Column_End : Natural;
      Kernel : Kernel_Handle;
   end record;

   package Location_Idle is new Gtk.Main.Idle (Location_Idle_Data);

   function Location_Callback (D : Location_Idle_Data) return Boolean;
   --  Idle callback used to scroll the source editors.

   function File_Edit_Callback (D : Location_Idle_Data) return Boolean;
   --  Emit the File_Edited signal.

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child;
   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
      return Node_Ptr;
   --  Support functions for the MDI

   procedure On_Open_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Open menu

   procedure On_Open_From_Path
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Open From Path menu

   procedure On_New_View
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->New View menu

   procedure On_New_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->New menu

   procedure On_Save
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save menu

   procedure On_Save_As
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save As... menu

   procedure On_Save_All_Editors
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save All Editors menu

   procedure On_Save_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save All menu

   procedure On_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Print menu

   procedure On_Cut
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Cut menu

   procedure On_Copy
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Copy menu

   procedure On_Paste
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Paste menu

   procedure On_Select_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Select All menu

   procedure On_Goto_Line_Current_Editor
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Navigate->Goto Line... menu

   procedure On_Goto_Declaration
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Navigate->Goto Declaration menu
   --  Goto the declaration of the entity under the cursor in the current
   --  editor.

   procedure On_Goto_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Navigate->Goto Body menu
   --  Goto the next body of the entity under the cursor in the current
   --  editor.

   procedure On_Generate_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Generate Body menu

   procedure On_Pretty_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Pretty Print menu

   procedure On_Comment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Comment Lines menu

   procedure On_Uncomment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Uncomment Lines menu

   procedure Comment_Uncomment
     (Kernel : Kernel_Handle; Comment : Boolean);
   --  Comment or uncomment the current selection, if any.
   --  Auxiliary procedure for On_Comment_Lines and On_Uncomment_Lines.

   procedure On_Edit_File
     (Widget : access GObject_Record'Class;
      Context : Selection_Context_Access);
   --  Edit a file (from a contextual menu)

   procedure On_Lines_Revealed
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Display the line numbers.

   procedure Source_Editor_Contextual
     (Object  : access GObject_Record'Class;
      Context : access Selection_Context'Class;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class);
   --  Generate the contextual menu entries for contextual menus in other
   --  modules than the source editor.

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget) return Selection_Context_Access;
   --  Create the current context for Glide_Kernel.Get_Current_Context

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Editor : access Source_Editor_Box_Record'Class)
      return Selection_Context_Access;
   --  Same as above.

   function New_View
     (Kernel  : access Kernel_Handle_Record'Class;
      Current : Source_Editor_Box) return Source_Box;
   --  Create a new view for Current and add it in the MDI.
   --  The current editor is the focus child in the MDI.
   --  If Add is True, the Box is added to the MDI.

   procedure New_View
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class);
   --  Create a new view for the current editor and add it in the MDI.
   --  The current editor is the focus child in the MDI. If the focus child
   --  is not an editor, nothing happens.

   function Delete_Callback
     (Widget : access Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues) return Boolean;
   --  Callback for the "delete_event" signal.

   procedure File_Edited_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_edited" signal.

   procedure File_Closed_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_closed" signal.

   procedure File_Changed_On_Disk_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_changed_on_disk" signal.

   procedure File_Saved_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_saved" signal.

   procedure Preferences_Changed
     (K : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Called when the preferences have changed.

   function Edit_Command_Handler
     (Kernel  : access Kernel_Handle_Record'Class;
      Command : String;
      Args    : GNAT.OS_Lib.Argument_List) return String;
   --  Interactive command handler for the source editor module.

   procedure Add_To_Recent_Menu
     (Kernel : access Kernel_Handle_Record'Class;
      File   : String);
   --  Add an entry for File to the Recent menu, if needed.

   function Console_Has_Focus
     (Kernel : access Kernel_Handle_Record'Class) return Boolean;
   --  Return True if the focus MDI child is an interactive console.

   function Find_Mark (Identifier : String) return Mark_Identifier_Record;
   --  Find the mark corresponding to Identifier, or return an empty
   --  record.

   procedure Fill_Marks (Kernel : Kernel_Handle; File : String);
   --  Create the marks on the buffer corresponding to File, if File has just
   --  been open.

   function Get_Filename (Child : MDI_Child) return String;
   --  If Child is a file editor, return the corresponding filename,
   --  otherwise return an empty string.

   function Expand_Aliases_Entities
     (Data : Event_Data; Special : Character) return String;
   --  Does the expansion of special entities in the aliases.

   type On_Recent is new Menu_Callback_Record with record
      Kernel : Kernel_Handle;
   end record;
   procedure Activate (Callback : access On_Recent; Item : String);

   ------------------
   -- Get_Filename --
   ------------------

   function Get_Filename (Child : MDI_Child) return String is
   begin
      if Child /= null
        and then Get_Widget (Child).all in Source_Box_Record'Class
      then
         return Get_Filename (Source_Box (Get_Widget (Child)).Editor);
      else
         return "";
      end if;
   end Get_Filename;

   -----------------------
   -- Console_Has_Focus --
   -----------------------

   function Console_Has_Focus
     (Kernel : access Kernel_Handle_Record'Class) return Boolean
   is
      Child  : constant MDI_Child := Get_Focus_Child (Get_MDI (Kernel));
      Widget : Gtk_Widget;
   begin
      if Child = null then
         return False;
      else
         Widget := Get_Widget (Child);

         return Widget.all in Interactive_Console_Record'Class
           and then Is_Editable (Interactive_Console (Widget));
      end if;
   end Console_Has_Focus;

   ----------
   -- Free --
   ----------

   procedure Free (X : in out Mark_Identifier_Record) is
   begin
      Free (X.File);
   end Free;

   ---------------
   -- Find_Mark --
   ---------------

   function Find_Mark (Identifier : String) return Mark_Identifier_Record is
      use type Mark_Identifier_List.List_Node;

      Id          : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Mark_Node   : Mark_Identifier_List.List_Node;
      Mark_Record : Mark_Identifier_Record;
   begin
      Mark_Node := Mark_Identifier_List.First (Id.Stored_Marks);

      while Mark_Node /= Mark_Identifier_List.Null_Node loop
         Mark_Record := Mark_Identifier_List.Data (Mark_Node);

         if Image (Mark_Record.Id) = Identifier then
            return Mark_Record;
         end if;

         Mark_Node := Mark_Identifier_List.Next (Mark_Node);
      end loop;

      return Mark_Identifier_Record'
        (Id     => 0,
         Child  => null,
         File   => null,
         Mark   => null,
         Line   => 0,
         Column => 0,
         Length => 0);
   end Find_Mark;

   --------------------------
   -- Edit_Command_Handler --
   --------------------------

   function Edit_Command_Handler
     (Kernel  : access Kernel_Handle_Record'Class;
      Command : String;
      Args    : GNAT.OS_Lib.Argument_List) return String
   is
      use String_List_Utils.String_List;
      Id       : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Node          : Natural;
      Filename      : GNAT.OS_Lib.String_Access;
      Error_Message : Basic_Types.String_Access;
      Line     : Natural := 1;
      Length   : Natural := 0;
      Column   : Natural := 1;
      Force    : Boolean;
      All_Save : Boolean;

      function Parse_Argument (Arg : String) return Natural;
      --  Parse a numerical argument, produce an error message corresponding
      --  to Arg if parsing fails.

      function Parse_Argument (Arg : String) return Natural is
      begin
         Node := Node + 1;
         if Node > Args'Last then
            Error_Message := new String'
              (Command & ": " & (-"option ") & Arg & (-" requires a value"));
            return 0;
         end if;

         return Natural'Value (Args (Node).all);
      exception
         when others =>
            Error_Message := new String'
              (Command
               & ": " & (-"option ") & Arg & (-" requires a numerical value"));
            return 0;
      end Parse_Argument;

   begin
      if Command = "edit" or else Command = "create_mark" then
         Node := Args'First;

         while Node <= Args'Last loop
            if Args (Node).all = "-c" then
               Column := Parse_Argument ("-c");
            elsif Args (Node).all = "-l" then
               Line := Parse_Argument ("-l");
            elsif Args (Node).all = "-L" then
               Length := Parse_Argument ("-L");
            elsif Filename = null then
               declare
                  File : constant String := Args (Node).all;
               begin
                  if Is_Absolute_Path (File) then
                     Filename := new String'(Normalize_Pathname (File));
                  else
                     declare
                        F : constant String := Get_Full_Path_From_File
                          (Registry        => Get_Registry (Kernel),
                           Filename        => File,
                           Use_Source_Path => True,
                           Use_Object_Path => False);
                     begin
                        if Is_Absolute_Path (F) then
                           Filename := new String'(F);
                        else
                           Filename := new String'(File);
                        end if;
                     end;
                  end if;
               end;

            else
               Free (Filename);
               return Command & ": " & (-"too many parameters");
            end if;

            if Error_Message /= null then
               declare
                  Message : constant String := Error_Message.all;
               begin
                  Free (Filename);
                  Free (Error_Message);
                  return Message;
               end;
            end if;

            Node := Node + 1;
         end loop;

         if Filename /= null then
            if Command = "edit" then
               if Length = 0 then
                  Open_File_Editor
                    (Kernel,
                     Filename.all,
                     Line,
                     Column,
                     Enable_Navigation => False,
                     From_Path => True);
               else
                  Open_File_Editor
                    (Kernel,
                     Filename.all,
                     Line,
                     Column,
                     Column + Length,
                     Enable_Navigation => False,
                     From_Path => True);
               end if;

            elsif Command = "create_mark" then
               declare
                  Box         : Source_Box;
                  Child       : MDI_Child;
                  Mark_Record : Mark_Identifier_Record;
                  File        : constant String := Get_Full_Path_From_File
                    (Registry        => Get_Registry (Kernel),
                     Filename        => Filename.all,
                     Use_Source_Path => True,
                     Use_Object_Path => False);

               begin
                  if File /= "" then
                     Free (Filename);
                     Filename := new String'(File);
                  end if;

                  Child := Find_Editor (Kernel, Filename.all);

                  --  Create a new mark record and insert it in the list.

                  Mark_Record.File := new String'(Filename.all);
                  Mark_Record.Id := Id.Next_Mark_Id;

                  Id.Next_Mark_Id := Id.Next_Mark_Id + 1;

                  Mark_Record.Length := Length;

                  if Child /= null then
                     Mark_Record.Child := Child;
                     Box := Source_Box (Get_Widget (Child));
                     Mark_Record.Mark :=
                       Create_Mark (Box.Editor, Line, Column);
                  else
                     Mark_Record.Line := Line;
                     Mark_Record.Column := Column;
                     Add_Unique_Sorted (Id.Unopened_Files, Filename.all);
                  end if;

                  Mark_Identifier_List.Append (Id.Stored_Marks, Mark_Record);

                  Free (Filename);
                  return Image (Mark_Record.Id);
               end;
            end if;

            Free (Filename);

            return "";
         else
            return Command & ": " & (-"missing parameter file_name");
         end if;

      elsif Command = "close"
        or else Command = "edit_undo"
        or else Command = "edit_redo"
      then
         Filename := Args (Args'First);

         if Command = "close" then
            Close_File_Editors (Kernel, Filename.all);
         else
            declare
               Child : MDI_Child;
               Box   : Source_Box;
            begin
               Child := Find_Editor (Kernel, Filename.all);

               if Child = null then
                  return "file not open";
               end if;

               Box := Source_Box (Get_Widget (Child));

               if Command = "edit_redo" then
                  Redo (Box.Editor);
               elsif Command = "edit_undo" then
                  Undo (Box.Editor);
               end if;
            end;
         end if;

         return "";

      elsif Command = "goto_mark" then
         Filename := Args (Args'First);

         declare
            Mark_Record : constant Mark_Identifier_Record :=
              Find_Mark (Filename.all);
         begin
            if Mark_Record.Child /= null then
               Raise_Child (Mark_Record.Child);
               Set_Focus_Child (Mark_Record.Child);
               Grab_Focus (Source_Box (Get_Widget (Mark_Record.Child)).Editor);

               --  If the Length is null, we set the length to 1, otherwise
               --  the cursor is not visible.

               Scroll_To_Mark
                 (Source_Box (Get_Widget (Mark_Record.Child)).Editor,
                  Mark_Record.Mark,
                  Mark_Record.Length);

            else
               if Mark_Record.File /= null
                 and then Is_In_List
                 (Id.Unopened_Files, Mark_Record.File.all)
               then
                  Open_File_Editor (Kernel,
                                    Mark_Record.File.all,
                                    Mark_Record.Line,
                                    Mark_Record.Column,
                                    Mark_Record.Column + Mark_Record.Length,
                                    From_Path => True);

                  --  At this point, Open_File_Editor should have caused the
                  --  propagation of the File_Edited signal, which provokes a
                  --  call to Fill_Marks in File_Edited_Cb.
                  --  Therefore the Mark_Record might not be valid beyond this
                  --  point.
               end if;
            end if;

            return "";
         end;

      elsif Command = "get_chars" or else Command = "replace_text" then
         declare
            Before : Integer := -1;
            After  : Integer := -1;
            Text   : Basic_Types.String_Access;
         begin
            Node := Args'First;

            while Node <= Args'Last loop
               if Args (Node).all = "-c" then
                  Column := Parse_Argument ("-c");

               elsif Args (Node).all = "-l" then
                  Line := Parse_Argument ("-l");

               elsif Args (Node).all = "-b" then
                  Before := Parse_Argument ("-b");

               elsif Args (Node).all = "-a" then
                  After := Parse_Argument ("-a");

               elsif Filename = null then
                  Filename := new String'(Args (Node).all);

               elsif Text = null then
                  declare
                     T : constant String := Args (Node).all;
                  begin
                     Text := new String'(T (T'First + 1 .. T'Last - 1));
                  end;

               else
                  Free (Text);
                  Free (Filename);
                  return Command & ": " & (-"too many parameters");
               end if;

               if Error_Message /= null then
                  declare
                     Message : constant String := Error_Message.all;
                  begin
                     Free (Filename);
                     Free (Error_Message);
                     Free (Text);
                     return Message;
                  end;
               end if;

               Node := Node + 1;
            end loop;

            if Filename /= null then
               declare
                  Mark_Record : constant Mark_Identifier_Record
                    := Find_Mark (Filename.all);
                  Child       : MDI_Child;
               begin
                  if Mark_Record.Mark /= null
                    and then Mark_Record.Child /= null
                  then
                     Free (Filename);

                     if Command = "get_chars" then
                        Free (Text);
                        return
                          Get_Chars
                            (Source_Box
                                 (Get_Widget (Mark_Record.Child)).Editor,
                             Mark_Record.Mark,
                             Before, After);
                     else
                        if Text = null then
                           Text := new String'("");
                        end if;

                        Replace_Slice
                          (Source_Box (Get_Widget (Mark_Record.Child)).Editor,
                           Mark_Record.Mark,
                           Before, After,
                           Text.all);

                        Free (Text);
                        return "";
                     end if;
                  else
                     Child := Find_Editor (Kernel, Filename.all);
                     Free (Filename);

                     if Child /= null then
                        if Command = "get_chars" then
                           Free (Text);
                           return Get_Chars
                             (Source_Box (Get_Widget (Child)).Editor,
                              Line, Column,
                              Before, After);
                        else
                           if Text = null then
                              Text := new String'("");
                           end if;

                           Replace_Slice_At_Position
                             (Source_Box (Get_Widget (Child)).Editor,
                              Line, Column,
                              Before, After,
                              Text.all);

                           Free (Text);
                           return "";
                        end if;
                     end if;

                     Free (Text);
                     return "mark not found";
                  end if;
               end;

            else
               return "invalid position";
            end if;
         end;

      elsif Command = "get_line"
        or else Command = "get_column"
        or else Command = "get_file"
      then
         Filename := Args (Args'First);

         declare
            Mark_Record : constant Mark_Identifier_Record :=
              Find_Mark (Filename.all);
         begin
            if Mark_Record.File = null then
               return -"mark not found";
            else
               if Command = "get_line" then
                  if Mark_Record.Child /= null then
                     return Image
                       (Get_Line
                        (Source_Box (Get_Widget (Mark_Record.Child)).Editor,
                         Mark_Record.Mark));
                  else
                     return Image (Mark_Record.Line);
                  end if;
               elsif Command = "get_column" then
                  if Mark_Record.Child /= null then
                     return Image
                       (Get_Column
                        (Source_Box (Get_Widget (Mark_Record.Child)).Editor,
                         Mark_Record.Mark));
                  else
                     return Image (Mark_Record.Column);
                  end if;
               else
                  if Mark_Record.File = null then
                     return "";
                  else
                     return Mark_Record.File.all;
                  end if;
               end if;
            end if;
         end;

      elsif Command = "get_last_line" then
         Filename := Args (Args'First);

         declare
            Child : constant MDI_Child := Find_Editor (Kernel, Filename.all);
         begin
            if Child = null then
               declare
                  A : GNAT.OS_Lib.String_Access := Read_File (Filename.all);
                  N : Natural := 0;
               begin
                  if A /= null then
                     for J in A'Range loop
                        if A (J) = ASCII.LF then
                           N := N + 1;
                        end if;
                     end loop;

                     Free (A);

                     if N = 0 then
                        N := 1;
                     end if;

                     return Image (N);
                  else
                     return -"file not found or not opened";
                  end if;
               end;
            else
               return Image
                 (Get_Last_Line (Source_Box (Get_Widget (Child)).Editor));
            end if;
         end;

      elsif Command = "get_buffer" then
         Filename := Args (Args'First);

         declare
            Child : constant MDI_Child := Find_Editor (Kernel, Filename.all);
            A : GNAT.OS_Lib.String_Access;
         begin
            if Child /= null then
               return Get_Buffer (Source_Box (Get_Widget (Child)).Editor);
            else
               --  The buffer is not currently open, read directly from disk.

               A := Read_File (Filename.all);
               if A /= null then
                  declare
                     S : constant String := A.all;
                  begin
                     Free (A);
                     return S;
                  end;

               else
                  return -"file not found";
               end if;
            end if;
         end;

      elsif Command = "save" then
         Force := True;
         All_Save := False;

         Node := Args'First;

         while Node <= Args'Last loop
            if Args (Node).all = "-i" then
               Force := False;
            elsif Args (Node).all = "all" then
               All_Save := True;
            else
               return -"save: invalid parameter";
            end if;

            Node := Node + 1;
         end loop;

         if All_Save then
            if Save_All_MDI_Children (Kernel, Force) then
               return "";
            else
               return -"cancelled";
            end if;
         else
            declare
               Child : constant MDI_Child := Find_Current_Editor (Kernel);
            begin
               if Child = null then
                  return -"no file selected";
               else
                  return To_Lower (Save_Return_Value'Image
                    (Save_Child (Kernel, Child, False)));
               end if;
            end;
         end if;

      else
         return -"command not recognized: " & Command;
      end if;
   end Edit_Command_Handler;

   ----------------
   -- Fill_Marks --
   ----------------

   procedure Fill_Marks
     (Kernel : Kernel_Handle;
      File   : String)
   is
      Id    : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);

      use Mark_Identifier_List;

      Box         : Source_Box;
      Child       : MDI_Child;
      Node        : List_Node;
      Mark_Record : Mark_Identifier_Record;
   begin
      if Is_In_List (Id.Unopened_Files, File) then
         Child := Find_Editor (Kernel, File);

         if Child = null then
            return;
         end if;

         Box := Source_Box (Get_Widget (Child));
         Remove_From_List (Id.Unopened_Files, File);

         Node := First (Id.Stored_Marks);

         while Node /= Null_Node loop
            Mark_Record := Data (Node);

            if Mark_Record.File /= null
              and then Mark_Record.File.all = File
            then
               Set_Data
                 (Node,
                  Mark_Identifier_Record'
                    (Id => Mark_Record.Id,
                     Child => Child,
                     File => new String'(File),
                     Line => Mark_Record.Line,
                     Mark =>
                       Create_Mark
                         (Box.Editor,
                          Mark_Record.Line, Mark_Record.Column),
                     Column => Mark_Record.Column,
                     Length => Mark_Record.Length));
            end if;

            Node := Next (Node);
         end loop;
      end if;
   end Fill_Marks;

   --------------------
   -- File_Edited_Cb --
   --------------------

   procedure File_Edited_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Id    : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Infos : Line_Information_Data;
      File  : constant String := Get_String (Nth (Args, 1));
   begin
      if Id.Display_Line_Numbers then
         Create_Line_Information_Column
           (Kernel,
            File,
            Src_Editor_Module_Name,
            Stick_To_Data => False,
            Every_Line    => True,
            Normalize     => False);

         Infos := new Line_Information_Array (1 .. 1);
         Infos (1).Text := new String'("   1");

         Add_Line_Information
           (Kernel,
            File,
            Src_Editor_Module_Name,
            Infos);

         Unchecked_Free (Infos);
      end if;

      Fill_Marks (Kernel, File);
   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end File_Edited_Cb;

   -----------------------------
   -- File_Changed_On_Disk_Cb --
   -----------------------------

   procedure File_Changed_On_Disk_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      File  : constant String := Get_String (Nth (Args, 1));
      Iter  : Child_Iterator := First_Child (Get_MDI (Kernel));
      Child : MDI_Child;
      Box   : Source_Box;
   begin
      if File = "" then
         return;
      end if;

      loop
         Child := Get (Iter);

         exit when Child = null;

         if File_Equal (File, Get_Filename (Child)) then
            Box := Source_Box (Get_Widget (Child));
            Check_Timestamp (Box.Editor);
         end if;

         Next (Iter);
      end loop;
   end File_Changed_On_Disk_Cb;

   --------------------
   -- File_Closed_Cb --
   --------------------

   procedure File_Closed_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget, Kernel);

      use Mark_Identifier_List;

      Id    : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      File  : constant String := Get_String (Nth (Args, 1));

      Node        : List_Node;
      Mark_Record : Mark_Identifier_Record;
      Added       : Boolean := False;

      Box         : Source_Box;

   begin
      --  If the file has marks, store their location.

      Node := First (Id.Stored_Marks);

      while Node /= Null_Node loop
         if Data (Node).File /= null
           and then Data (Node).File.all = File
         then
            Mark_Record := Data (Node);

            if Mark_Record.Child /= null
              and then Mark_Record.Mark /= null
            then
               Box := Source_Box (Get_Widget (Mark_Record.Child));

               Mark_Record.Line := Get_Line (Box.Editor, Mark_Record.Mark);
               Mark_Record.Column :=
                 Get_Column (Box.Editor, Mark_Record.Mark);
            end if;

            Set_Data (Node,
                      Mark_Identifier_Record'
                        (Id => Mark_Record.Id,
                         Child => null,
                         File => new String'(File),
                         Line => Mark_Record.Line,
                         Mark => null,
                         Column => Mark_Record.Column,
                         Length => Mark_Record.Length));

            if not Added then
               Add_Unique_Sorted (Id.Unopened_Files, File);
               Added := True;
            end if;
         end if;

         Node := Next (Node);
      end loop;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end File_Closed_Cb;

   -------------------
   -- File_Saved_Cb --
   -------------------

   procedure File_Saved_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      File  : constant String := Get_String (Nth (Args, 1));
      Base  : constant String := Base_Name (File);
   begin
      --  Insert the saved file in the Recent menu.

      if File /= ""
        and then not (Base'Length > 2
                      and then Base (Base'First .. Base'First + 1) = ".#")
      then
         Add_To_Recent_Menu (Kernel, File);
      end if;
   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end File_Saved_Cb;

   ---------------------
   -- Delete_Callback --
   ---------------------

   function Delete_Callback
     (Widget : access Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues) return Boolean
   is
      pragma Unreferenced (Params);
   begin
      return Save_Function
        (Get_Kernel (Source_Box (Widget).Editor), Gtk_Widget (Widget), False)
        = Cancel;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end Delete_Callback;

   ------------------------
   -- File_Edit_Callback --
   ------------------------

   function File_Edit_Callback (D : Location_Idle_Data) return Boolean is
   begin
      if Is_Valid_Location (D.Edit, D.Line) then
         Set_Screen_Location (D.Edit, D.Line, D.Column, Force_Focus => False);

         if D.Column_End /= 0
           and then Is_Valid_Location (D.Edit, D.Line, D.Column_End)
         then
            Select_Region (D.Edit, D.Line, D.Column, D.Line, D.Column_End);
         end if;
      end if;

      File_Edited (Get_Kernel (D.Edit), Get_Filename (D.Edit));

      return False;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end File_Edit_Callback;

   ------------------
   -- Load_Desktop --
   ------------------

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child
   is
      Src    : Source_Box := null;
      File   : Glib.String_Ptr;
      Str    : Glib.String_Ptr;
      Id     : Idle_Handler_Id;
      Line   : Positive := 1;
      Column : Positive := 1;
      Child  : MDI_Child;
      pragma Unreferenced (Id, MDI);

      Dummy  : Boolean;
      pragma Unreferenced (Dummy);
   begin
      if Node.Tag.all = "Source_Editor" then
         File := Get_Field (Node, "File");

         if File /= null then
            Str := Get_Field (Node, "Line");

            if Str /= null then
               Line := Positive'Value (Str.all);
            end if;

            Str := Get_Field (Node, "Column");

            if Str /= null then
               Column := Positive'Value (Str.all);
            end if;

            if not Is_Open (User, File.all) then
               Src := Open_File (User, File.all, False);
               Child := Find_Editor (User, File.all);
            else
               Child := Find_Editor (User, File.all);
               declare
                  Edit  : constant Source_Editor_Box :=
                    Get_Source_Box_From_MDI (Child);
               begin
                  Src := New_View (User, Edit);
               end;
            end if;

            if Src /= null then
               Dummy := File_Edit_Callback
                 ((Src.Editor, Line, Column, 0, User));

               --  Add the location in the navigations button.
               declare
                  Args   : Argument_List (1 .. 6);
               begin
                  Args (1 .. 6) :=
                    (new String'("edit"),
                     new String'("-l"),
                     new String'(Image (Line)),
                     new String'("-c"),
                     new String'(Image (Column)),
                     new String'(File.all));

                  Interpret_Command (User, "add_location_command", Args);
                  Free (Args);
               end;
            end if;
         end if;
      end if;

      return Child;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return null;
   end Load_Desktop;

   -----------------------
   -- On_Lines_Revealed --
   -----------------------

   procedure On_Lines_Revealed
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Context      : constant Selection_Context_Access :=
        To_Selection_Context_Access (Get_Address (Nth (Args, 1)));
      Area_Context : File_Area_Context_Access;
      Infos        : Line_Information_Data;
      Line1, Line2 : Integer;

   begin
      if Context.all in File_Area_Context'Class then
         Area_Context := File_Area_Context_Access (Context);

         Get_Area (Area_Context, Line1, Line2);

         Infos := new Line_Information_Array (Line1 .. Line2);

         for J in Infos'Range loop
            Infos (J).Text := new String'(Image (J));
         end loop;

         if Has_File_Information (Area_Context) then
            Add_Line_Information
              (Kernel,
               Directory_Information (Area_Context) &
               File_Information (Area_Context),
               Src_Editor_Module_Name,
               Infos,
               Normalize => False);
         end if;

         Unchecked_Free (Infos);
      end if;
   end On_Lines_Revealed;

   ------------------
   -- Save_Desktop --
   ------------------

   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class) return Node_Ptr
   is
      N, Child     : Node_Ptr;
      Line, Column : Positive;
      Editor       : Source_Editor_Box;

   begin
      if Widget.all in Source_Box_Record'Class then
         N := new Node;
         N.Tag := new String'("Source_Editor");

         Editor := Source_Box (Widget).Editor;

         Child := new Node;
         Child.Tag := new String'("File");
         Child.Value := new String'(Get_Filename (Editor));
         Add_Child (N, Child);

         Get_Cursor_Location (Editor, Line, Column);

         Child := new Node;
         Child.Tag := new String'("Line");
         Child.Value := new String'(Image (Line));
         Add_Child (N, Child);

         Child := new Node;
         Child.Tag := new String'("Column");
         Child.Value := new String'(Image (Column));
         Add_Child (N, Child);

         Child := new Node;
         Child.Tag := new String'("Column_End");
         Child.Value := new String'(Image (Column));
         Add_Child (N, Child);

         return N;
      end if;

      return null;
   end Save_Desktop;

   -----------------------------
   -- Get_Source_Box_From_MDI --
   -----------------------------

   function Get_Source_Box_From_MDI
     (Child : Gtkada.MDI.MDI_Child) return Source_Editor_Box is
   begin
      if Child = null then
         return null;
      else
         return Source_Box (Get_Widget (Child)).Editor;
      end if;
   end Get_Source_Box_From_MDI;

   -------------------------
   -- Find_Current_Editor --
   -------------------------

   function Find_Current_Editor
     (Kernel : access Kernel_Handle_Record'Class) return MDI_Child is
   begin
      return Find_MDI_Child_By_Tag (Get_MDI (Kernel), Source_Box_Record'Tag);
   end Find_Current_Editor;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Box    : out Source_Box;
      Editor : Source_Editor_Box) is
   begin
      Box := new Source_Box_Record;
      Initialize (Box, Editor);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Box    : access Source_Box_Record'Class;
      Editor : Source_Editor_Box) is
   begin
      Gtk.Box.Initialize_Hbox (Box);
      Box.Editor := Editor;
   end Initialize;

   --------------
   -- New_View --
   --------------

   function New_View
     (Kernel  : access Kernel_Handle_Record'Class;
      Current : Source_Editor_Box) return Source_Box
   is
      MDI     : constant MDI_Window := Get_MDI (Kernel);
      Editor  : Source_Editor_Box;
      Box     : Source_Box;
      Child   : MDI_Child;

   begin
      if Current = null then
         return null;
      end if;

      declare
         Title : constant String := Get_Filename (Current);
      begin
         Create_New_View (Editor, Kernel, Current);
         Gtk_New (Box, Editor);
         Attach (Editor, Box);

         Child := Put
           (MDI, Box,
            Focus_Widget => Gtk_Widget (Get_View (Editor)),
            Default_Width  => Get_Pref (Kernel, Default_Widget_Width),
            Default_Height => Get_Pref (Kernel, Default_Widget_Height));

         Set_Icon (Child, Gdk_New_From_Xpm_Data (editor_xpm));
         Set_Focus_Child (Child);

         declare
            Im : constant String := Image (Get_Ref_Count (Editor));
         begin
            Set_Title
              (Child,
               Title & " <" & Im & ">",
               Base_Name (Title) & " <" & Im & ">");
         end;

         Gtkada.Handlers.Return_Callback.Object_Connect
           (Box,
            "delete_event",
            Delete_Callback'Access,
            Gtk_Widget (Box),
            After => False);
      end;

      return Box;
   end New_View;

   procedure New_View
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Current : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
      Box     : Source_Box;
      pragma Unreferenced (Box);

   begin
      if Current /= null then
         Box := New_View (Kernel, Current);
      end if;
   end New_View;

   -------------------
   -- Save_Function --
   -------------------

   function Save_Function
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget;
      Force  : Boolean := False) return Save_Return_Value
   is
      Success        : Boolean;
      Containing_Box : constant Source_Box := Source_Box (Child);
      Box            : constant Source_Editor_Box := Containing_Box.Editor;
      Button         : Message_Dialog_Buttons;
   begin
      if Force then
         if Needs_To_Be_Saved (Box) then
            Save_To_File (Box, Success => Success);
         end if;

      elsif Needs_To_Be_Saved (Box) then
         Button := Message_Dialog
           (Msg            =>
              (-"Do you want to save file ") & Get_Filename (Box) & " ?",
            Dialog_Type    => Confirmation,
            Buttons        =>
              Button_Yes or Button_All or Button_No or Button_Cancel,
            Default_Button => Button_Cancel,
            Parent         => Get_Main_Window (Kernel));

         case Button is
            when Button_Yes =>
               Save_To_File (Box, Success => Success);
               return Saved;

            when Button_No =>
               return Not_Saved;

            when Button_All =>
               Save_To_File (Box, Success => Success);
               return Save_All;

            when others =>
               return Cancel;

         end case;
      end if;

      return Saved;
   end Save_Function;

   ------------------------
   -- Create_File_Editor --
   ------------------------

   function Create_File_Editor
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : String;
      Create_New : Boolean := True) return Source_Editor_Box
   is
      Success     : Boolean;
      Editor      : Source_Editor_Box;
      File_Exists : Boolean := False;

   begin
      if File /= "" then
         File_Exists := Is_Regular_File (File);
      end if;

      --  Create a new editor only if the file exists or we are asked to
      --  create a new empty one anyway.

      if File_Exists or else Create_New then
         Gtk_New (Editor, Kernel_Handle (Kernel));
      else
         return null;
      end if;

      if File_Exists then
         Load_File (Editor, File,
                    Force_Focus => not Console_Has_Focus (Kernel),
                    Success     => Success);

         if not Success then
            Destroy (Editor);
            Editor := null;
         end if;

      else
         Load_Empty_File (Editor, File, Get_Language_Handler (Kernel));
      end if;

      return Editor;
   end Create_File_Editor;

   ------------------------
   -- Add_To_Recent_Menu --
   ------------------------

   procedure Add_To_Recent_Menu
     (Kernel : access Kernel_Handle_Record'Class; File : String) is
   begin
      Add_To_History (Kernel, Hist_Key, File);
   end Add_To_Recent_Menu;

   ---------------
   -- Open_File --
   ---------------

   function Open_File
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : String := "";
      Create_New : Boolean := True;
      Focus      : Boolean := True) return Source_Box
   is
      MDI        : constant MDI_Window := Get_MDI (Kernel);
      Editor     : Source_Editor_Box;
      Box        : Source_Box;
      Child      : MDI_Child;

   begin
      if File /= "" then
         Child := Find_Editor (Kernel, File);

         if Child /= null then
            Raise_Child (Child);

            if Focus then
               Set_Focus_Child (Child);
            end if;

            return Source_Box (Get_Widget (Child));
         end if;
      end if;

      Editor := Create_File_Editor (Kernel, File, Create_New);

      --  If we have created an editor, put it into a box, and give it
      --  to the MDI to handle

      if Editor /= null then
         Gtk_New (Box, Editor);
         Attach (Editor, Box);

         Child := Put
           (MDI, Box, Focus_Widget => Gtk_Widget (Get_View (Editor)),
            Default_Width  => Get_Pref (Kernel, Default_Widget_Width),
            Default_Height => Get_Pref (Kernel, Default_Widget_Height));
         Set_Icon (Child, Gdk_New_From_Xpm_Data (editor_xpm));

         if Focus then
            Set_Focus_Child (Child);
         end if;

         Raise_Child (Child);

         if File /= "" then
            Set_Title (Child, File, Base_Name (File));
            File_Edited (Kernel, File);
         else
            --  Determine the number of "Untitled" files open.

            declare
               Iterator    : Child_Iterator := First_Child (MDI);
               The_Child   : MDI_Child;
               Nb_Untitled : Natural := 0;
               No_Name     : constant String := -"Untitled";
            begin
               The_Child := Get (Iterator);

               while The_Child /= null loop
                  if The_Child /= Child
                    and then Get_Widget (The_Child).all in
                    Source_Box_Record'Class
                    and then Get_Filename (The_Child) = ""
                  then
                     Nb_Untitled := Nb_Untitled + 1;
                  end if;

                  Next (Iterator);
                  The_Child := Get (Iterator);
               end loop;

               if Nb_Untitled = 0 then
                  Set_Title (Child, No_Name);
                  Set_File_Identifier (Editor, No_Name);
               else
                  declare
                     Identifier : constant String :=
                       No_Name & " (" & Image (Nb_Untitled + 1) & ")";
                  begin
                     Set_Title (Child, Identifier);
                     Set_File_Identifier (Editor, Identifier);
                  end;
               end if;

               Set_Filename (Editor, Get_Filename (Child));
               File_Edited (Kernel, Get_Title (Child));
            end;
         end if;

         Gtkada.Handlers.Return_Callback.Object_Connect
           (Box,
            "delete_event",
            Delete_Callback'Access,
            Gtk_Widget (Box),
            After => False);

         if File /= "" then
            Add_To_Recent_Menu (Kernel, File);
         end if;

      else
         Console.Insert
           (Kernel, (-"Cannot open file ") & "'" & File & "'",
            Add_LF => True,
            Mode   => Error);
      end if;

      return Box;
   end Open_File;

   -----------------------
   -- Location_Callback --
   -----------------------

   function Location_Callback (D : Location_Idle_Data) return Boolean is
   begin
      if D.Line /= 0 and then Is_Valid_Location (D.Edit, D.Line) then
         Set_Screen_Location
           (D.Edit, D.Line, D.Column,
            not (Console_Has_Focus (D.Kernel)));

         if D.Column_End /= 0
           and then Is_Valid_Location (D.Edit, D.Line, D.Column_End)
         then
            Select_Region (D.Edit, D.Line, D.Column, D.Line, D.Column_End);
         end if;
      end if;

      return False;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end Location_Callback;

   ------------------
   -- Save_To_File --
   ------------------

   procedure Save_To_File
     (Kernel  : access Kernel_Handle_Record'Class;
      Name    : String := "";
      Success : out Boolean)
   is
      Child  : constant MDI_Child := Find_Current_Editor (Kernel);
      Source : Source_Editor_Box;

   begin
      if Child = null then
         return;
      end if;

      Source := Source_Box (Get_Widget (Child)).Editor;

      declare
         Old_Name : constant String := Get_Filename (Source);
      begin
         Save_To_File (Source, Name, Success);

         declare
            New_Name : constant String := Get_Filename (Source);
         begin
            --  Update the title, in case "save as..." was used.

            if Old_Name /= New_Name then
               Set_Title (Child, New_Name, Base_Name (New_Name));
               Change_Project_Dir (Kernel, Dir_Name (New_Name));
            end if;
         end;
      end;
   end Save_To_File;

   ------------------
   -- On_Open_File --
   ------------------

   procedure On_Open_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
   begin
      declare
         Filename : constant String :=
           Select_File
             (Title             => -"Open File",
              Parent            => Get_Main_Window (Kernel),
              Use_Native_Dialog => Get_Pref (Kernel, Use_Native_Dialogs),
              Kind              => Open_File,
              History           => Get_History (Kernel));

      begin
         if Filename = "" then
            return;
         end if;

         Open_File_Editor (Kernel, Filename, From_Path => False);
         Change_Project_Dir (Kernel, Dir_Name (Filename));
      end;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Open_File;

   -----------------------
   -- On_Open_From_Path --
   -----------------------

   procedure On_Open_From_Path
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Label  : Gtk_Label;
      Button : Gtk_Widget;
      pragma Unreferenced (Widget, Button);

      Open_File_Dialog         : Gtk_Dialog;
      Open_File_Entry          : Gtkada_Entry;

   begin
      Gtk_New (Open_File_Dialog,
               Title  => -"Open file from project",
               Parent => Get_Main_Window (Kernel),
               Flags  => Modal or Destroy_With_Parent);
      Set_Default_Size (Open_File_Dialog, 300, 200);
      Set_Position (Open_File_Dialog, Win_Pos_Mouse);

      Gtk_New (Label, -"Enter file name (use <tab> for completion):");
      Pack_Start (Get_Vbox (Open_File_Dialog), Label, Expand => False);

      Gtk_New (Open_File_Entry);
      Set_Activates_Default
        (Get_Entry (Get_Combo (Open_File_Entry)), True);
      Pack_Start (Get_Vbox (Open_File_Dialog), Open_File_Entry,
                  Fill => True, Expand => True);
      Get_History (Get_History (Kernel).all,
                   Open_From_Path_History,
                   Get_Combo (Open_File_Entry));

      Button := Add_Button (Open_File_Dialog, Stock_Ok, Gtk_Response_OK);
      Button := Add_Button
        (Open_File_Dialog, Stock_Cancel, Gtk_Response_Cancel);
      Set_Default_Response (Open_File_Dialog, Gtk_Response_OK);

      Grab_Focus (Get_Entry (Get_Combo (Open_File_Entry)));
      Show_All (Open_File_Dialog);

      declare
         List1 : String_Array_Access := Get_Source_Files
           (Project   => Get_Project (Kernel),
            Recursive => True,
            Full_Path => False);
         List2 : String_Array_Access :=
           Get_Predefined_Source_Files (Get_Registry (Kernel));
      begin
         Set_Completions
           (Open_File_Entry, new String_Array'(List1.all & List2.all));
         Unchecked_Free (List1);
         Unchecked_Free (List2);
      end;

      if Run (Open_File_Dialog) = Gtk_Response_OK then
         declare
            Text : constant String :=
              Get_Text (Get_Entry (Get_Combo (Open_File_Entry)));
         begin
            Add_To_History
              (Get_History (Kernel).all, Open_From_Path_History,  Text);
            Open_File_Editor (Kernel, Text, From_Path => True);
         end;
      end if;

      Destroy (Open_File_Dialog);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Open_From_Path;

   --------------
   -- Activate --
   --------------

   procedure Activate (Callback : access On_Recent; Item : String) is
   begin
      Open_File_Editor (Callback.Kernel, Item, From_Path => False);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end Activate;

   -----------------
   -- On_New_File --
   -----------------

   procedure On_New_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Editor : Source_Box;
      pragma Unreferenced (Widget, Editor);
   begin
      Editor := Open_File (Kernel, File => "");

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_New_File;

   -------------
   -- On_Save --
   -------------

   procedure On_Save
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Success : Boolean;
   begin
      Save_To_File (Kernel, Success => Success);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save;

   ----------------
   -- On_Save_As --
   ----------------

   procedure On_Save_As
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Success : Boolean;
      Source  : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));

   begin
      if Source /= null then
         declare
            New_Name : constant String :=
              Select_File
                (Title             => -"Save File As",
                 Parent            => Get_Main_Window (Kernel),
                 Use_Native_Dialog => Get_Pref (Kernel, Use_Native_Dialogs),
                 Kind              => Save_File,
                 History           => Get_History (Kernel));

         begin
            if New_Name = "" then
               return;
            else
               Save_To_File (Kernel, New_Name, Success);
            end if;
         end;
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save_As;

   -----------------
   -- On_Save_All --
   -----------------

   procedure On_Save_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Ignore : Boolean;
      pragma Unreferenced (Widget, Ignore);

   begin
      Ignore := Save_All_MDI_Children (Kernel, Force => True);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save_All;

   --------------
   -- On_Print --
   --------------

   procedure On_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Success : Boolean;
      Child   : constant MDI_Child := Find_Current_Editor (Kernel);
      Source  : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));

   begin
      if Source /= null then
         if Save_Child (Kernel, Child, False) /= Cancel then
            declare
               Cmd : Argument_List_Access := Argument_String_To_List
                 (Get_Pref (Kernel, Print_Command) & " " &
                  Get_Filename (Source));
            begin
               Launch_Process
                 (Kernel, Cmd (Cmd'First).all, Cmd (Cmd'First + 1 .. Cmd'Last),
                  Name => "", Success => Success);
               Free (Cmd);
            end;
         end if;
      end if;
   end On_Print;

   -------------------------
   -- On_Save_All_Editors --
   -------------------------

   procedure On_Save_All_Editors
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Ignore : Boolean;
      pragma Unreferenced (Widget, Ignore);

   begin
      Ignore := Save_All_Editors (Kernel, Force => True);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save_All_Editors;

   ------------
   -- On_Cut --
   ------------

   procedure On_Cut
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Source : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Source /= null then
         Cut_Clipboard (Source);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Cut;

   -------------
   -- On_Copy --
   -------------

   procedure On_Copy
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Source : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Source /= null then
         Copy_Clipboard (Source);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Copy;

   --------------
   -- On_Paste --
   --------------

   procedure On_Paste
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Source : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Source /= null then
         Paste_Clipboard (Source);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Paste;

   -------------------
   -- On_Select_All --
   -------------------

   procedure On_Select_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Source : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Source /= null then
         Select_All (Source);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Select_All;

   -----------------
   -- On_New_View --
   -----------------

   procedure On_New_View
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
   begin
      New_View (Kernel);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_New_View;

   ---------------------------------
   -- On_Goto_Line_Current_Editor --
   ---------------------------------

   procedure On_Goto_Line_Current_Editor
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));

   begin
      if Editor /= null then
         On_Goto_Line (Editor => GObject (Editor), Kernel => Kernel);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Goto_Line_Current_Editor;

   -------------------------
   -- On_Goto_Declaration --
   -------------------------

   procedure On_Goto_Declaration
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Editor = null then
         return;
      end if;

      Goto_Declaration_Or_Body
        (Kernel,
         To_Body => False,
         Editor  => Editor,
         Context => Entity_Selection_Context_Access
           (Default_Factory (Kernel, Editor)));

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Goto_Declaration;

   ------------------
   -- On_Goto_Body --
   ------------------

   procedure On_Goto_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Editor = null then
         return;
      end if;

      Goto_Declaration_Or_Body
        (Kernel, To_Body => True,
         Editor => Editor,
         Context => Entity_Selection_Context_Access
           (Default_Factory (Kernel, Editor)));

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Goto_Body;

   ----------------------
   -- Generate_Body_Cb --
   ----------------------

   procedure Generate_Body_Cb (Data : Process_Data; Status : Integer) is
      Body_Name : constant String := Other_File_Name
        (Data.Kernel, Data.Name.all, Full_Name => True);
   begin
      if Status = 0
        and then Is_Regular_File (Body_Name)
      then
         Open_File_Editor (Data.Kernel, Body_Name, From_Path => False);
      end if;
   end Generate_Body_Cb;

   ----------------------
   -- On_Generate_Body --
   ----------------------

   procedure On_Generate_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Context : constant Selection_Context_Access :=
        Get_Current_Context (Kernel);

   begin
      if Context = null
        or else not (Context.all in File_Selection_Context'Class)
      then
         Console.Insert
           (Kernel, -"No file selected, cannot generate body", Mode => Error);
         return;
      end if;

      declare
         File_Context : constant File_Selection_Context_Access :=
           File_Selection_Context_Access (Context);
         Filename     : constant String := File_Information (File_Context);
         File         : constant String :=
           Directory_Information (File_Context) & Filename;
         Success      : Boolean;
         Args         : Argument_List (1 .. 4);
         Lang         : String := Get_Language_From_File
           (Get_Language_Handler (Kernel), File);

      begin
         if File = "" then
            Console.Insert
              (Kernel, -"No file name, cannot generate body", Mode => Error);
            return;
         end if;

         To_Lower (Lang);

         if Lang /= "ada" then
            Console.Insert
              (Kernel, -"Body generation of non Ada file not yet supported",
               Mode => Error);
            return;
         end if;

         if not Save_All_MDI_Children
           (Kernel, Force => Get_Pref (Kernel, Auto_Save))
         then
            return;
         end if;

         Args (1) := new String'("stub");
         Args (2) := new String'
           ("-P" & Project_Name
            (Get_Project_From_File (Get_Registry (Kernel), File)));
         Args (3) := new String'(File);
         Args (4) := new String'(Dir_Name (File));

         declare
            Scenar : Argument_List_Access := Argument_String_To_List
              (Scenario_Variables_Cmd_Line (Kernel, GNAT_Syntax));
         begin
            Launch_Process
              (Kernel, "gnat", Args (1 .. 2) & Scenar.all & Args (3 .. 4),
               "", null,
               Generate_Body_Cb'Access, File, Success);
            Free (Args);
            Free (Scenar);
         end;

         if Success then
            Print_Message
              (Glide_Window (Get_Main_Window (Kernel)).Statusbar,
               Help, -"Generating body...");
         end if;
      end;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Generate_Body;

   ---------------------
   -- Pretty_Print_Cb --
   ---------------------

   procedure Pretty_Print_Cb (Data : Process_Data; Status : Integer) is
      function Pretty_Name (Name : String) return String;
      --  Return the name of the pretty printed file.

      function Pretty_Name (Name : String) return String is
      begin
         return Name & ".pp";
      end Pretty_Name;

   begin
      if Status = 0 then
         Open_File_Editor (Data.Kernel, Pretty_Name (Data.Name.all),
                           From_Path => True);
      end if;
   end Pretty_Print_Cb;

   -----------------------
   -- Comment_Uncomment --
   -----------------------

   procedure Comment_Uncomment
     (Kernel : Kernel_Handle; Comment : Boolean)
   is
      Context    : constant Selection_Context_Access :=
        Get_Current_Context (Kernel);

      Area         : File_Area_Context_Access;
      File_Context : File_Selection_Context_Access;
      Start_Line   : Integer;
      End_Line     : Integer;


      use String_List_Utils.String_List;
   begin
      if Context /= null
        and then Context.all in File_Selection_Context'Class
        and then Has_File_Information
          (File_Selection_Context_Access (Context))
        and then Has_Directory_Information
          (File_Selection_Context_Access (Context))
      then
         File_Context := File_Selection_Context_Access (Context);

         declare
            Lang       : Language_Access;
            File       : constant String :=
              Directory_Information (File_Context)
              & File_Information (File_Context);

            Lines      : List;
            Length     : Integer := 0;

         begin
            if Context.all in File_Area_Context'Class then
               Area := File_Area_Context_Access (Context);
               Get_Area (Area, Start_Line, End_Line);

            elsif Context.all in Entity_Selection_Context'Class
              and then Has_Line_Information
                (Entity_Selection_Context_Access (Context))
            then
               Start_Line := Line_Information
                 (Entity_Selection_Context_Access (Context));

               End_Line := Start_Line;
            else
               return;
            end if;

            Lang := Get_Language_From_File
              (Get_Language_Handler (Kernel), File);

            --  Create a list of lines, in order to perform the replace
            --  as a block.

            for J in Start_Line .. End_Line loop
               declare
                  Line : constant String :=
                    Interpret_Command
                      (Kernel, "get_chars " & File & " -l " & Image (J));

               begin
                  Length := Length + Line'Length;

                  if Line = "" then
                     Append (Lines, "");
                  else
                     if Comment then
                        Append (Lines, Comment_Line (Lang, Line));
                     else
                        Append (Lines, Uncomment_Line (Lang, Line));
                     end if;
                  end if;
               end;
            end loop;

            --  Create a String containing the modified lines.

            declare
               L : Integer := 0;
               N : List_Node := First (Lines);
            begin
               while N /= Null_Node loop
                  L := L + Data (N)'Length;
                  N := Next (N);
               end loop;

               declare
                  S    : String (1 .. L);
                  Args : Argument_List (1 .. 6);
               begin
                  N := First (Lines);
                  L := 1;

                  while N /= Null_Node loop
                     S (L .. L + Data (N)'Length - 1) := Data (N);
                     L := L + Data (N)'Length;
                     N := Next (N);
                  end loop;

                  Args := (1 => new String'(File),
                           2 => new String'("-l"),
                           3 => new String'(Image (Start_Line)),
                           4 => new String'("-a"),
                           5 => new String'(Image (Length)),
                           6 => new String'("""" & S & """"));

                  Interpret_Command (Kernel, "replace_text", Args);

                  Free (Args);
               end;
            end;
         end;
      end if;
   end Comment_Uncomment;

   ----------------------
   -- On_Comment_Lines --
   ----------------------

   procedure On_Comment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
   begin
      Comment_Uncomment (Kernel, Comment => True);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Comment_Lines;

   ------------------------
   -- On_Uncomment_Lines --
   ------------------------

   procedure On_Uncomment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

   begin
      Comment_Uncomment (Kernel, Comment => False);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Uncomment_Lines;

   ---------------------
   -- On_Pretty_Print --
   ---------------------

   procedure On_Pretty_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Context : constant Selection_Context_Access :=
        Get_Current_Context (Kernel);

   begin
      if Context = null
        or else not (Context.all in File_Selection_Context'Class)
      then
         Console.Insert
           (Kernel, -"No file selected, cannot pretty print",
            Mode => Error);
         return;
      end if;

      declare
         File_Context : constant File_Selection_Context_Access :=
           File_Selection_Context_Access (Context);
         Filename     : constant String := File_Information (File_Context);
         File         : constant String :=
           Directory_Information (File_Context) & Filename;
         Project      : constant String := Project_Name
           (Get_Project_From_File (Get_Registry (Kernel), Filename));
         Success      : Boolean;
         Args, Vars   : Argument_List_Access;
         Lang         : String := Get_Language_From_File
           (Get_Language_Handler (Kernel), File);

      begin
         if File = "" then
            Console.Insert
              (Kernel, -"No file name, cannot pretty print",
               Mode => Error);
            return;
         end if;

         To_Lower (Lang);

         if Lang /= "ada" then
            Console.Insert
              (Kernel, -"Pretty printing of non Ada file not yet supported",
               Mode => Error);
            return;
         end if;

         if not Save_All_MDI_Children
           (Kernel, Force => Get_Pref (Kernel, Auto_Save))
         then
            return;
         end if;

         if Project = "" then
            Args := new Argument_List'
              (new String'("pretty"), new String'(File));

         else
            Vars := Argument_String_To_List
              (Scenario_Variables_Cmd_Line (Kernel, GNAT_Syntax));
            Args := new Argument_List'
              ((1 => new String'("pretty"),
                2 => new String'("-P" & Project),
                3 => new String'(File)) & Vars.all);
            Unchecked_Free (Vars);
         end if;

         Launch_Process
           (Kernel, "gnat", Args.all, "", null,
            Pretty_Print_Cb'Access, File, Success);
         Free (Args);

         if Success then
            Print_Message
              (Glide_Window (Get_Main_Window (Kernel)).Statusbar,
               Help, -"Pretty printing...");
         end if;
      end;

   exception
      when E : others =>
         Pop_State (Kernel);
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Pretty_Print;

   -----------------
   -- Mime_Action --
   -----------------

   function Mime_Action
     (Kernel    : access Kernel_Handle_Record'Class;
      Mime_Type : String;
      Data      : GValue_Array;
      Mode      : Mime_Mode := Read_Write) return Boolean
   is
      pragma Unreferenced (Mode);

      Source    : Source_Box;
      Edit      : Source_Editor_Box;
      MDI       : constant MDI_Window := Get_MDI (Kernel);
      Tmp       : Boolean;
      pragma Unreferenced (Tmp);

   begin
      if Mime_Type = Mime_Source_File then
         declare
            File        : constant String  := Get_String (Data (Data'First));
            Line        : constant Gint    := Get_Int (Data (Data'First + 1));
            Column      : constant Gint    := Get_Int (Data (Data'First + 2));
            Column_End  : constant Gint    := Get_Int (Data (Data'First + 3));
            New_File    : constant Boolean :=
              Get_Boolean (Data (Data'First + 5));
            Iter        : Child_Iterator := First_Child (MDI);
            Child       : MDI_Child;
            No_Location : Boolean := False;

         begin
            if Line = -1 then
               --  Close all file editors corresponding to File.

               loop
                  Child := Get (Iter);

                  exit when Child = null;

                  if Get_Widget (Child).all in Source_Box_Record'Class
                    and then File_Equal (Get_Filename (Child), File)
                  then
                     Destroy (Source_Box (Get_Widget (Child)));
                  end if;

                  Next (Iter);
               end loop;

               return True;

            else
               if Line = 0 and then Column = 0 then
                  No_Location := True;
               end if;

               if Console_Has_Focus (Kernel) then
                  --  Only grab again the focus on Child (in Location_Callback)
                  --  if the focus was changed by Open_File, and an interactive
                  --  console had the focus previousely.

                  Child := Get_Focus_Child (Get_MDI (Kernel));
               end if;

               Source := Open_File
                 (Kernel, File,
                  Create_New => New_File,
                  Focus      => (not No_Location) and then (Child = null));

               if Child /= null then
                  Set_Focus_Child (Child);
               end if;

               if Source /= null then
                  Edit := Source.Editor;
               end if;

               if Edit /= null
                 and then not No_Location
               then
                  Trace (Me, "Setup editor to go to line,col="
                         & Line'Img & Column'Img);
                  Tmp := Location_Callback
                    ((Edit,
                      Natural (Line),
                      Natural (Column),
                      Natural (Column_End),
                      Kernel_Handle (Kernel)));
               end if;

               return Edit /= null;
            end if;
         end;

      elsif Mime_Type = Mime_File_Line_Info then
         declare
            File  : constant String  := Get_String (Data (Data'First));
            Id    : constant String  := Get_String (Data (Data'First + 1));
            Info  : constant Line_Information_Data :=
              To_Line_Information (Get_Address (Data (Data'First + 2)));
            Stick_To_Data : constant Boolean :=
              Get_Boolean (Data (Data'First + 3));
            Every_Line : constant Boolean :=
              Get_Boolean (Data (Data'First + 4));
            Child : MDI_Child;

            procedure Apply_Mime_On_Child (Child : MDI_Child);
            --  Apply the mime information on Child.

            procedure Apply_Mime_On_Child (Child : MDI_Child) is
            begin
               if Info'First = 0 then
                  Create_Line_Information_Column
                    (Source_Box (Get_Widget (Child)).Editor,
                     Id,
                     Stick_To_Data,
                     Every_Line);

               elsif Info'Length = 0 then
                  Remove_Line_Information_Column
                    (Source_Box (Get_Widget (Child)).Editor, Id);

               else
                  Add_File_Information
                    (Source_Box (Get_Widget (Child)).Editor,
                     Id, Info);
               end if;
            end Apply_Mime_On_Child;

         begin
            --  Look for the corresponding file editor.

            Child := Find_Editor (Kernel, File);

            if Child /= null then
               --  The editor was found.
               Apply_Mime_On_Child (Child);

               return True;
            end if;
         end;
      end if;

      return False;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end Mime_Action;

   ------------------
   -- On_Edit_File --
   ------------------

   procedure On_Edit_File
     (Widget  : access GObject_Record'Class;
      Context : Selection_Context_Access)
   is
      pragma Unreferenced (Widget);

      File     : constant File_Selection_Context_Access :=
        File_Selection_Context_Access (Context);
      Location : File_Location_Context_Access;
      Line     : Natural;

   begin
      Trace (Me, "On_Edit_File: " & File_Information (File));

      if File.all in File_Location_Context'Class then
         Location := File_Location_Context_Access (File);

         if Has_Line_Information (Location) then
            Line := Line_Information (Location);
         else
            Line := 1;
         end if;

         Open_File_Editor
           (Get_Kernel (Context),
            Directory_Information (File) & File_Information (File),
            Line      => Line,
            Column    => Column_Information (Location),
            From_Path => False);

      else
         Open_File_Editor
           (Get_Kernel (Context),
            Directory_Information (File) & File_Information (File),
            From_Path => False);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Edit_File;

   ------------------------------
   -- Source_Editor_Contextual --
   ------------------------------

   procedure Source_Editor_Contextual
     (Object  : access GObject_Record'Class;
      Context : access Selection_Context'Class;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      pragma Unreferenced (Object);
      File  : File_Selection_Context_Access;
      Mitem : Gtk_Menu_Item;

   begin
      if Context.all in File_Selection_Context'Class then
         File := File_Selection_Context_Access (Context);

         if Has_Directory_Information (File)
           and then Has_File_Information (File)
         then
            Gtk_New (Mitem, -"Edit " &
                     Locale_To_UTF8 (Base_Name (File_Information (File))));
            Append (Menu, Mitem);
            Context_Callback.Connect
              (Mitem, "activate",
               Context_Callback.To_Marshaller (On_Edit_File'Access),
               Selection_Context_Access (Context));
         end if;
      end if;
   end Source_Editor_Contextual;

   ---------------------
   -- Default_Factory --
   ---------------------

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Editor : access Source_Editor_Box_Record'Class)
      return Selection_Context_Access is
   begin
      return Get_Contextual_Menu (Kernel, Editor, null, null);
   end Default_Factory;

   ---------------------
   -- Default_Factory --
   ---------------------

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget) return Selection_Context_Access
   is
      C : constant Source_Box := Source_Box (Child);
   begin
      return Default_Factory (Kernel, C.Editor);
   end Default_Factory;

   -----------------------------
   -- Expand_Aliases_Entities --
   -----------------------------

   function Expand_Aliases_Entities
     (Data : Event_Data; Special : Character) return String
   is
      Box : Source_Editor_Box;
      W   : Gtk_Widget;
      Line, Column : Positive;
   begin
      if Get_Widget (Data).all in Source_View_Record'Class then
         W := Get_Parent (Get_Widget (Data));
         while W.all not in Source_Box_Record'Class loop
            W := Get_Parent (W);
         end loop;
         Box := Source_Box (W).Editor;

         case Special is
            when 'l' =>
               Get_Cursor_Location (Box, Line, Column);
               return Image (Line);

            when 'c' =>
               Get_Cursor_Location (Box, Line, Column);
               return Image (Column);

            when 'f' =>
               return Base_Name (Get_Filename (Box));

            when 'd' =>
               return Dir_Name (Get_Filename (Box));

            when 'p' =>
               return Project_Name
                 (Get_Project_From_File
                  (Get_Registry (Get_Kernel (Data)),
                   Get_Filename (Box),
                   Root_If_Not_Found => True));

            when 'P' =>
               return Project_Path
                 (Get_Project_From_File
                  (Get_Registry (Get_Kernel (Data)),
                   Get_Filename (Box),
                   Root_If_Not_Found => True));

            when others =>
               return Invalid_Expansion;
         end case;

      else
         return Invalid_Expansion;
      end if;
   end Expand_Aliases_Entities;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class)
   is
      File             : constant String := '/' & (-"File") & '/';
      Save             : constant String := File & (-"Save...") & '/';
      Edit             : constant String := '/' & (-"Edit") & '/';
      Navigate         : constant String := '/' & (-"Navigate") & '/';
      Mitem            : Gtk_Menu_Item;
      Button           : Gtk_Button;
      Toolbar          : constant Gtk_Toolbar := Get_Toolbar (Kernel);
      Undo_Redo        : Undo_Redo_Information;
      Selector         : Scope_Selector;
      Extra            : Files_Extra_Scope;
      Recent_Menu_Item : Gtk_Menu_Item;

   begin
      Src_Editor_Module_Id := new Source_Editor_Module_Record;
      Source_Editor_Module (Src_Editor_Module_Id).Kernel :=
        Kernel_Handle (Kernel);

      Register_Module
        (Module                  => Src_Editor_Module_Id,
         Kernel                  => Kernel,
         Module_Name             => Src_Editor_Module_Name,
         Priority                => Default_Priority,
         Contextual_Menu_Handler => Source_Editor_Contextual'Access,
         Mime_Handler            => Mime_Action'Access,
         MDI_Child_Tag           => Source_Box_Record'Tag,
         Default_Context_Factory => Default_Factory'Access,
         Save_Function           => Save_Function'Access);
      Glide_Kernel.Kernel_Desktop.Register_Desktop_Functions
        (Save_Desktop'Access, Load_Desktop'Access);

      --  Menus

      Register_Menu (Kernel, File, -"_Open...",  Stock_Open,
                     On_Open_File'Access, null,
                     GDK_F3, Ref_Item => -"Save...");
      Register_Menu (Kernel, File, -"Open _From Project...",  Stock_Open,
                     On_Open_From_Path'Access, null,
                     GDK_F3, Shift_Mask, Ref_Item => -"Save...");

      Recent_Menu_Item :=
        Register_Menu (Kernel, File, -"_Recent", "", null,
                       Ref_Item   => -"Open From Project...",
                       Add_Before => False);
      Associate (Get_History (Kernel).all,
                 Hist_Key,
                 Recent_Menu_Item,
                 new On_Recent'(Menu_Callback_Record with
                                Kernel => Kernel_Handle (Kernel)));

      Register_Menu (Kernel, File, -"_New", Stock_New, On_New_File'Access,
                     Ref_Item => -"Open...");
      Register_Menu (Kernel, File, -"New _View", "", On_New_View'Access,
                     Ref_Item => -"Open...");

      Register_Menu (Kernel, File, -"_Save", Stock_Save,
                     On_Save'Access, null,
                     GDK_S, Control_Mask, Ref_Item => -"Save...");
      Register_Menu (Kernel, File, -"Save _As...", Stock_Save_As,
                     On_Save_As'Access, Ref_Item => -"Save...");
      Register_Menu (Kernel, Save, -"All _Editors", "",
                     On_Save_All_Editors'Access, Sensitive => False,
                     Ref_Item => -"Desktop");
      Register_Menu (Kernel, Save, -"_All", "",
                     On_Save_All'Access, Ref_Item => -"Desktop");

      Register_Menu (Kernel, File, -"_Print", Stock_Print, On_Print'Access,
                     Ref_Item => -"Exit");
      Gtk_New (Mitem);
      Register_Menu (Kernel, File, Mitem, Ref_Item => -"Exit");

      --  Note: callbacks for the Undo/Redo menu items will be added later
      --  by each source editor.

      Undo_Redo.Undo_Menu_Item :=
        Register_Menu (Kernel, Edit, -"_Undo", Stock_Undo,
                       null, null,
                       GDK_Z, Control_Mask, Ref_Item => -"Preferences",
                       Sensitive => False);
      Undo_Redo.Redo_Menu_Item :=
        Register_Menu (Kernel, Edit, -"_Redo", Stock_Redo,
                       null, null,
                       GDK_R, Control_Mask, Ref_Item => -"Preferences",
                       Sensitive => False);

      Gtk_New (Mitem);
      Register_Menu
        (Kernel, Edit, Mitem, Ref_Item => "Redo", Add_Before => False);

      Register_Menu (Kernel, Edit, -"_Cut",  Stock_Cut,
                     On_Cut'Access, null,
                     GDK_Delete, Shift_Mask,
                     Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"C_opy",  Stock_Copy,
                     On_Copy'Access, null,
                     GDK_Insert, Control_Mask,
                     Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"P_aste",  Stock_Paste,
                     On_Paste'Access, null,
                     GDK_Insert, Shift_Mask,
                     Ref_Item => -"Preferences");

      --  ??? This should be bound to Ctrl-A, except this would interfer with
      --  Emacs keybindings for people who want to use them.
      Register_Menu (Kernel, Edit, -"_Select All",  "",
                     On_Select_All'Access, Ref_Item => -"Preferences");

      Gtk_New (Mitem);
      Register_Menu (Kernel, Edit, Mitem, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Edit, -"Comment _Lines", "",
                     On_Comment_Lines'Access, null,
                     GDK_minus, Control_Mask, Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"Uncomment L_ines", "",
                     On_Uncomment_Lines'Access, null,
                     GDK_underscore, Control_Mask, Ref_Item => -"Preferences");

      Gtk_New (Mitem);
      Register_Menu (Kernel, Edit, Mitem, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Edit, -"_Generate Body", "",
                     On_Generate_Body'Access, Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"P_retty Print", "",
                     On_Pretty_Print'Access, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Navigate, -"Goto _Line...", Stock_Jump_To,
                     On_Goto_Line_Current_Editor'Access, null,
                     GDK_G, Control_Mask,
                     Ref_Item => -"Goto File Spec<->Body");
      Register_Menu (Kernel, Navigate, -"Goto _Declaration", Stock_Home,
                     On_Goto_Declaration'Access, Ref_Item => -"Goto Line...");
      Register_Menu (Kernel, Navigate, -"Goto _Body", "",
                     On_Goto_Body'Access, Ref_Item => -"Goto Line...");

      --  Toolbar buttons

      Button := Insert_Stock
        (Toolbar, Stock_New, -"Create a New File", Position => 0);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_New_File'Access),
         Kernel_Handle (Kernel));

      Button := Insert_Stock
        (Toolbar, Stock_Open, -"Open a File", Position => 1);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Open_File'Access),
         Kernel_Handle (Kernel));

      Button := Insert_Stock
        (Toolbar, Stock_Save, -"Save Current File", Position => 2);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Save'Access),
         Kernel_Handle (Kernel));

      Insert_Space (Toolbar, Position => 3);
      Undo_Redo.Undo_Button := Insert_Stock
        (Toolbar, Stock_Undo, -"Undo Previous Action", Position => 4);
      Set_Sensitive (Undo_Redo.Undo_Button, False);
      Undo_Redo.Redo_Button := Insert_Stock
        (Toolbar, Stock_Redo, -"Redo Previous Action", Position => 5);
      Set_Sensitive (Undo_Redo.Redo_Button, False);

      Insert_Space (Toolbar, Position => 6);
      Button := Insert_Stock
        (Toolbar, Stock_Cut, -"Cut to Clipboard", Position => 7);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Cut'Access),
         Kernel_Handle (Kernel));
      Button := Insert_Stock
        (Toolbar, Stock_Copy, -"Copy to Clipboard", Position => 8);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Copy'Access),
         Kernel_Handle (Kernel));
      Button := Insert_Stock
        (Toolbar, Stock_Paste, -"Paste from Clipboard", Position => 9);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Paste'Access),
         Kernel_Handle (Kernel));
      Kernel_Callback.Connect
        (Kernel, File_Saved_Signal,
         File_Saved_Cb'Access,
         Kernel_Handle (Kernel));

      Undo_Redo_Data.Set (Kernel, Undo_Redo, Undo_Redo_Id);

      Preferences_Changed (Kernel, Kernel_Handle (Kernel));

      Kernel_Callback.Connect
        (Kernel, Preferences_Changed_Signal,
         Kernel_Callback.To_Marshaller (Preferences_Changed'Access),
         User_Data   => Kernel_Handle (Kernel));

      Source_Editor_Module (Src_Editor_Module_Id).File_Closed_Id :=
        Kernel_Callback.Connect
          (Kernel,
           File_Closed_Signal,
           File_Closed_Cb'Access,
           Kernel_Handle (Kernel));

      Kernel_Callback.Connect
        (Kernel,
         File_Changed_On_Disk_Signal,
         File_Changed_On_Disk_Cb'Access,
         Kernel_Handle (Kernel));

      Source_Editor_Module (Src_Editor_Module_Id).File_Edited_Id :=
        Kernel_Callback.Connect
          (Kernel,
           File_Edited_Signal,
           File_Edited_Cb'Access,
           Kernel_Handle (Kernel));

      Register_Command
        (Kernel,
         Command      => "edit",
         Usage        => "edit [-l line] [-c column] [-L Len] file_name",
         Description  => -"Open a file editor for file_name." & ASCII.LF
           & (-"Len is the number of characters to select after the cursor."),
         Minimum_Args => 1,
         Maximum_Args => 7,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command => "create_mark",
         Usage   =>
           "create_mark [-l line] [-c column] [-L length] file_name",
         Description =>
           -("Create a mark for file_name, at position given by line and"
             & " column."
             & ASCII.LF
             & "Length corresponds to the text length to highlight"
             & " after the mark." & ASCII.LF
             & "The identifier of the mark is returned." & ASCII.LF
             & "Use the command goto_mark to jump to this mark."),
         Minimum_Args => 1,
         Maximum_Args => 7,
         Handler => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "src.highlight",
         Usage        => "src.highlight file [line] category",
         Description  =>
           -("Marks a line to belong to a highlighting category."
             & ASCII.LF
             & "If line is not specified, mark all lines in file."),

         Minimum_Args => 2,
         Maximum_Args => 3,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "src.unhighlight",
         Usage        => "src.unhighlight file [line] category",
         Description  =>
           -("Unmarks the line for the specified category"
             & ASCII.LF
             & "If line is not specified, unmark all lines in file."),
         Minimum_Args => 2,
         Maximum_Args => 3,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "src.register_highlighting",
         Usage        => "src.register_highlighting category color",
         Description  => -("Create a new highlighting category with"
                           & " the given color. The format for color is"
                           & " ""#RRGGBB""."),
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "goto_mark",
         Usage        => "goto_mark identifier",
         Description  =>
           -"Jump to the location of the mark corresponding to identifier.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_chars",
         Usage        => "get_chars {mark_identifier | -l line -c col} "
                         & "[-b before] [-a after]",
         Description  =>
           -("Get the characters around a certain mark or position."
             & ASCII.LF
             & "Returns string between <before> characters before the mark"
             & ASCII.LF
             & "and <after> characters after the position." & ASCII.LF
             & "If <before> or <after> is omitted, the bounds will be"
             & ASCII.LF
             & "at the beginning and/or the end of the line."),
         Minimum_Args => 0,
         Maximum_Args => 8,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_line",
         Usage        => "get_line mark",
         Description  => -"Returns the current line of mark.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_column",
         Usage        => "get_column mark",
         Description  => -"Returns the current column of mark.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_file",
         Usage        => "get_file mark",
         Description  => -"Returns the current file of mark.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_last_line",
         Usage        => "get_last_line file",
         Description  => -"Returns the number of the last line in file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_buffer",
         Usage        => "get_buffer file",
         Description  =>
           -"Returns the text contained in the current buffer for file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "replace_text",
         Usage        => "replace_text {mark_identifier | -l line -c col} "
                         & "[-b before] [-a after] file ""text""",
         Description  =>
           -("Replace the characters around a certain mark or position."
             & ASCII.LF
             & "Replace string between <before> characters before the mark"
             & ASCII.LF
             & "and <after> characters after the position." & ASCII.LF
             & "If <before> or <after> is omitted, the bounds will be"
             & ASCII.LF
             & "at the beginning and/or the end of the line."),
         Minimum_Args => 2,
         Maximum_Args => 10,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "edit_undo",
         Usage        => "edit_undo file",
         Description  => -"Undo the last edition command for file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "edit_redo",
         Usage        => "edit_redo file",
         Description  => -"Redo the last edition command for file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "close",
         Usage        => "close file_name",
         Description  => -"Close all file editors for file_name.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "save",
         Usage        => "save [-i] [all]",
         Description  => -("Save current or all files." & ASCII.LF
                           & "  -i: prompt before each save."),
         Minimum_Args => 0,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      --  Register the search functions

      Gtk_New (Selector, Kernel);
      Gtk_New (Extra, Kernel);

      declare
         Name  : constant String := -"Current File";
         Name2 : constant String := -"Files From Project";
         Name3 : constant String := -"Files...";
      begin
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name'Length,
               Label             => Name,
               Factory           => Current_File_Factory'Access,
               Extra_Information => Gtk_Widget (Selector),
               Id                => Src_Editor_Module_Id,
               Mask              => All_Options));
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name2'Length,
               Label             => Name2,
               Factory           => Files_From_Project_Factory'Access,
               Extra_Information => Gtk_Widget (Selector),
               Id                => null,
               Mask              => All_Options
                 and not Search_Backward));
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name3'Length,
               Label             => Name3,
               Factory           => Files_Factory'Access,
               Extra_Information => Gtk_Widget (Extra),
               Id                => null,
               Mask              => All_Options
                 and not Search_Backward));
      end;

      --  Register the aliases special entities

      Register_Special_Alias_Entity
        (Kernel, -"Current line",   'l', Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Current column", 'c', Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Current file",   'f', Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Project for the current file", 'p',
         Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Full path of project for the current file", 'P',
         Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Directory of current file", 'd',
         Expand_Aliases_Entities'Access);
   end Register_Module;

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (K : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (K);
      Id                        : Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Pref_Display_Line_Numbers : constant Boolean :=
        Get_Pref (Kernel, Display_Line_Numbers);

      use String_List_Utils.String_List;
   begin
      if Pref_Display_Line_Numbers = Id.Display_Line_Numbers then
         return;
      end if;

      Id.Display_Line_Numbers := Pref_Display_Line_Numbers;

      --  Connect necessary signal to display line numbers.
      if Pref_Display_Line_Numbers then
         if Id.Source_Lines_Revealed_Id = No_Handler then
            Id.Source_Lines_Revealed_Id :=
              Kernel_Callback.Connect
                (Kernel,
                 Source_Lines_Revealed_Signal,
                 On_Lines_Revealed'Access,
                 Kernel);

            declare
               Files : List := Open_Files (Kernel);
               Node  : List_Node;
            begin
               Node := First (Files);

               while Node /= Null_Node loop
                  Create_Line_Information_Column
                    (Kernel,
                     Data (Node),
                     Src_Editor_Module_Name,
                     Stick_To_Data => False,
                     Every_Line    => True,
                     Normalize     => False);
                  Node := Next (Node);
               end loop;

               Free (Files);
            end;
         end if;

      elsif Id.Source_Lines_Revealed_Id /= No_Handler then
         Gtk.Handlers.Disconnect
           (Kernel, Id.Source_Lines_Revealed_Id);
         Id.Source_Lines_Revealed_Id := No_Handler;

         Remove_Line_Information_Column (Kernel, "", Src_Editor_Module_Name);
      end if;
   end Preferences_Changed;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Id : in out Source_Editor_Module_Record) is
   begin
      String_List_Utils.String_List.Free (Id.Unopened_Files);
      Mark_Identifier_List.Free (Id.Stored_Marks);
   end Destroy;

   -----------------
   -- Find_Editor --
   -----------------

   function Find_Editor
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      File   : String) return Gtkada.MDI.MDI_Child
   is
      Iter  : Child_Iterator := First_Child (Get_MDI (Kernel));
      Child : MDI_Child;

   begin
      if File = "" then
         return null;
      end if;

      if File /= Base_Name (File) then
         loop
            Child := Get (Iter);

            exit when Child = null
              or else File_Equal (Get_Filename (Child), File);

            Next (Iter);
         end loop;

         return Child;

      else
         loop
            Child := Get (Iter);

            exit when Child = null
              or else File_Equal (Base_Name (Get_Filename (Child)), File)
              or else File = Get_Title (Child);

            Next (Iter);
         end loop;

         return Child;
      end if;
   end Find_Editor;

   ----------------
   -- Find_Child --
   ----------------

   function Find_Child
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      Editor : access Src_Editor_Box.Source_Editor_Box_Record'Class)
      return Gtkada.MDI.MDI_Child
   is
      Iter  : Child_Iterator := First_Child (Get_MDI (Kernel));
      Child : MDI_Child;

   begin
      loop
         Child := Get (Iter);

         exit when Child = null
           or else (Get_Widget (Child).all in Source_Box_Record'Class
                    and then Source_Box (Get_Widget (Child)).Editor =
                      Source_Editor_Box (Editor));
         Next (Iter);
      end loop;

      return Child;
   end Find_Child;

end Src_Editor_Module;
