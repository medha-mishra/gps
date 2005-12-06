-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2005                            --
--                              AdaCore                              --
--                                                                   --
-- GPS is free  software; you  can redistribute it and/or modify  it --
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

with Glib.Properties.Creation; use Glib.Properties.Creation;
with Glib.Xml_Int;             use Glib.Xml_Int;
with Gtk.Clipboard;            use Gtk.Clipboard;
with Gtk.Editable;             use Gtk.Editable;
with Gtk.Text_View;            use Gtk.Text_View;
with Gtk.Text_Buffer;          use Gtk.Text_Buffer;
with Gtk.Text_Iter;            use Gtk.Text_Iter;
with Gtk.Widget;               use Gtk.Widget;
with GNAT.OS_Lib;              use GNAT.OS_Lib;
with System;                   use System;
with Traces;                   use Traces;
with GPS.Intl;                 use GPS.Intl;
with GPS.Kernel.Console;       use GPS.Kernel.Console;
with GPS.Kernel.Hooks;         use GPS.Kernel.Hooks;
with GPS.Kernel.Preferences;   use GPS.Kernel.Preferences;
with XML_Parsers;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;

package body GPS.Kernel.Clipboard is

   Me : constant Debug_Handle := Create ("Clipboard");

   Clipboard_Size_Pref : Param_Spec_Int;

   function Convert is new Ada.Unchecked_Conversion
     (Clipboard_Access, System.Address);
   function Convert is new Ada.Unchecked_Conversion
     (System.Address, Clipboard_Access);
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Selection_List, Selection_List_Access);
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Clipboard_Record, Clipboard_Access);

   procedure Append_To_Clipboard (Clipboard : access Clipboard_Record);
   --  Add the contents of the Gtk.Clipboard to Clipboard

   procedure Preferences_Changed (Kernel : access Kernel_Handle_Record'Class);
   --  Called when the preferences have changed.

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Size : constant Integer :=
        Integer (Get_Pref (Clipboard_Size_Pref));
      Clipboard : constant Clipboard_Access := Get_Clipboard (Kernel);
      List      : Selection_List_Access;
   begin
      if Size /= Clipboard.List'Length then
         List := new Selection_List (1 .. Size);
         List (1 .. Integer'Min (Size, Clipboard.List'Length)) :=
           Clipboard.List (1 .. Integer'Min (Size, Clipboard.List'Length));
         Unchecked_Free (Clipboard.List);
         Clipboard.List := List;
         Run_Hook (Kernel, Clipboard_Changed_Hook);
      end if;
   end Preferences_Changed;

   ----------------------
   -- Create_Clipboard --
   ----------------------

   procedure Create_Clipboard
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Clipboard : constant Clipboard_Access := new Clipboard_Record;
      Size      : Integer;
      Filename  : constant String := Get_Home_Dir (Kernel) & "clipboards.xml";
      File, Child : Node_Ptr;
      Err         : String_Access;
   begin
      if Clipboard_Size_Pref = null then
         Clipboard_Size_Pref := Param_Spec_Int
           (Gnew_Int
              (Name    => "Clipboard-Size",
               Nick    => "Clipboard Size",
               Default => 10,
               Blurb   => -("Number of entries stored in the clipboard, that"
                            & " can be accessed through Paste Previous. The"
                            & " higher the size, the more memory GPS needs"),
               Minimum => 1,
               Maximum => 1_000));
         Register_Property
           (Kernel, Param_Spec (Clipboard_Size_Pref), -"General");

         Register_Hook_No_Args (Kernel, Clipboard_Changed_Hook);
      end if;

      Clipboard.Kernel := Kernel_Handle (Kernel);
      Size := Integer (Get_Pref (Clipboard_Size_Pref));
      Clipboard.List := new Selection_List (1 .. Size);
      Clipboard.Last_Paste := Clipboard.List'First;

      if Is_Regular_File (Filename) then
         Trace (Me, "Loading " & Filename);
         XML_Parsers.Parse (Filename, File, Err);
         if File = null then
            Insert (Kernel, Err.all, Mode => Error);
         else
            Child := File.Child;
            Size  := 1;
            while Size <= Clipboard.List'Last
              and then Child /= null
            loop
               Clipboard.List (Size) := new String'(Child.Value.all);
               if Get_Attribute (Child, "last", "false") = "true" then
                  Clipboard.Last_Paste := Size;
               end if;

               Size  := Size + 1;
               Child := Child.Next;
            end loop;
            Free (File);

            Run_Hook (Kernel, Clipboard_Changed_Hook);
         end if;
      end if;

      Destroy_Clipboard (Kernel);
      Kernel.Clipboard := Convert (Clipboard);

      Add_Hook (Kernel, Preferences_Changed_Hook,
                Wrapper (Preferences_Changed'Access),
                Name => "clipboard.preferences_changed");
   end Create_Clipboard;

   -----------------------
   -- Destroy_Clipboard --
   -----------------------

   procedure Destroy_Clipboard (Kernel : access Kernel_Handle_Record'Class) is
      Filename  : constant String := Get_Home_Dir (Kernel) & "clipboards.xml";
      File      : Node_Ptr;
      Child     : Node_Ptr;
      Clipboard : Clipboard_Access;
   begin
      if Kernel.Clipboard /= System.Null_Address then
         Clipboard := Convert (Kernel.Clipboard);

         Trace (Me, "Saving " & Filename);
         File := new Node;
         File.Tag := new String'("Clipboard");
         for L in Clipboard.List'Range loop
            if Clipboard.List (L) /= null then
               Child := new Node;
               Child.Tag := new String'("clipboard");

               if L = Clipboard.Last_Paste then
                  Set_Attribute (Child, "last", "true");
               end if;

               Child.Value := new String'(Clipboard.List (L).all);
               Add_Child (File, Child, Append => True);
            end if;
         end loop;
         Print (File, Filename);
         Free (File);

         for L in Clipboard.List'Range loop
            Free (Clipboard.List (L));
         end loop;
         Unchecked_Free (Clipboard.List);
         Unchecked_Free (Clipboard);
         Kernel.Clipboard := System.Null_Address;
      end if;
   end Destroy_Clipboard;

   -------------------
   -- Get_Clipboard --
   -------------------

   function Get_Clipboard
     (Kernel : access Kernel_Handle_Record'Class) return Clipboard_Access
   is
   begin
      return Convert (Kernel.Clipboard);
   end Get_Clipboard;

   -------------------------
   -- Append_To_Clipboard --
   -------------------------

   procedure Append_To_Clipboard (Clipboard : access Clipboard_Record) is
      Text : constant String := Wait_For_Text (Gtk.Clipboard.Get);
   begin
      if Clipboard.List (Clipboard.List'First) = null
        or else Text /= Clipboard.List (Clipboard.List'First).all
      then
         Free (Clipboard.List (Clipboard.List'Last));
         Clipboard.List (Clipboard.List'First + 1 .. Clipboard.List'Last) :=
           Clipboard.List (Clipboard.List'First .. Clipboard.List'Last - 1);
         Clipboard.List (Clipboard.List'First) := new String'
           (Wait_For_Text (Gtk.Clipboard.Get));

         Clipboard.Last_Paste  := Clipboard.List'First;
         Clipboard.Last_Widget := null;

         Run_Hook (Clipboard.Kernel, Clipboard_Changed_Hook);
      end if;
   end Append_To_Clipboard;

   ----------------------------
   -- Remove_Clipboard_Entry --
   ----------------------------

   procedure Remove_Clipboard_Entry
     (Clipboard : access Clipboard_Record; Index : Natural) is
   begin
      if Index in Clipboard.List'Range then
         Clipboard.List (Index .. Clipboard.List'Last - 1) :=
           Clipboard.List (Index + 1 .. Clipboard.List'Last);
         Clipboard.List (Clipboard.List'Last) := null;
         Run_Hook (Clipboard.Kernel, Clipboard_Changed_Hook);
      end if;
   end Remove_Clipboard_Entry;

   -------------------
   -- Cut_Clipboard --
   -------------------

   procedure Cut_Clipboard
     (Clipboard : access Clipboard_Record;
      Widget    : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      Buffer : Gtk_Text_Buffer;
   begin
      if Widget.all in Gtk_Editable_Record'Class then
         Cut_Clipboard (Gtk_Editable (Widget));
         Append_To_Clipboard (Clipboard);
      elsif Widget.all in Gtk_Text_View_Record'Class then
         Buffer := Get_Buffer (Gtk_Text_View (Widget));
         Cut_Clipboard
           (Buffer,
            Gtk.Clipboard.Get,
            Default_Editable => Get_Editable (Gtk_Text_View (Widget)));
         Append_To_Clipboard (Clipboard);
      end if;
   end Cut_Clipboard;

   --------------------
   -- Copy_Clipboard --
   --------------------

   procedure Copy_Clipboard
     (Clipboard : access Clipboard_Record;
      Widget    : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      Buffer : Gtk_Text_Buffer;
   begin
      if Widget.all in Gtk_Editable_Record'Class then
         Copy_Clipboard (Gtk_Editable (Widget));
         Append_To_Clipboard (Clipboard);
      elsif Widget.all in Gtk_Text_View_Record'Class then
         Buffer := Get_Buffer (Gtk_Text_View (Widget));
         Copy_Clipboard (Buffer, Gtk.Clipboard.Get);
         Append_To_Clipboard (Clipboard);
      end if;
   end Copy_Clipboard;

   ---------------------
   -- Paste_Clipboard --
   ---------------------

   procedure Paste_Clipboard
     (Clipboard     : access Clipboard_Record;
      Widget        : access Gtk.Widget.Gtk_Widget_Record'Class;
      Index_In_List : Natural := 0)
   is
      Buffer : Gtk_Text_Buffer;
      Result : Boolean;
      pragma Unreferenced (Result);
      Iter : Gtk_Text_Iter;
   begin
      Clipboard.Last_Is_From_System := False;

      if Index_In_List /= 0
        and then Index_In_List in Clipboard.List'Range
      then
         Clipboard.Last_Paste := Index_In_List;
         Run_Hook (Clipboard.Kernel, Clipboard_Changed_Hook);

         if Clipboard.Last_Paste not in Clipboard.List'Range
           or else Clipboard.List (Clipboard.Last_Paste) = null
         then
            Clipboard.Last_Paste := Clipboard.List'First;
            Run_Hook (Clipboard.Kernel, Clipboard_Changed_Hook);
         end if;
      end if;

      --  Should we paste the system clipboard instead of ours ?
      if Index_In_List = 0
        and then Wait_Is_Text_Available (Gtk.Clipboard.Get)
      then
         Clipboard.Last_Widget := Gtk_Widget (Widget);
         Clipboard.Last_Is_From_System := True;

         --  The following call is not really efficient, since Wait_For_Text
         --  really should be asynchronous. However, it works well almost
         --  always, since the clipboard is local on the machine and not huge
         --  in any case.
         Clipboard.Last_Length :=
           Wait_For_Text (Gtk.Clipboard.Get)'Length;

      elsif Clipboard.List (Clipboard.Last_Paste) /= null then
         Set_Text (Gtk.Clipboard.Get,
                   Clipboard.List (Clipboard.Last_Paste).all);
         Clipboard.Last_Widget := Gtk_Widget (Widget);
         Clipboard.Last_Length := Clipboard.List (Clipboard.Last_Paste)'Length;

      else
         Clipboard.Last_Widget := null;
      end if;

      if Clipboard.Last_Widget /= null then
         if Widget.all in Gtk_Editable_Record'Class then
            Paste_Clipboard (Gtk_Editable (Widget));
            Clipboard.Last_Position :=
              Integer (Get_Position (Gtk_Editable (Widget)));
         elsif Widget.all in Gtk_Text_View_Record'Class then
            Buffer := Get_Buffer (Gtk_Text_View (Widget));

            --  Delete the selected region if it exists.
            --  ??? This works around a bug which it seems is in gtk+,
            --  to be investigated.
            --  Scenario to reproduce the gtk bug : do a "select_region"
            --  and then a "paste_clipboard", twice. (See C703-005)

            if Selection_Exists (Buffer) then
               Result := Delete_Selection (Buffer, False, False);
            end if;

            Get_Iter_At_Mark (Buffer, Iter, Get_Insert (Buffer));
            Clipboard.Last_Position := Integer (Get_Offset (Iter))
              + Clipboard.Last_Length;

            --  The following call is asynchronous, which is why we had to
            --  compute the last position first
            Paste_Clipboard
              (Buffer, Gtk.Clipboard.Get,
               Default_Editable => Get_Editable (Gtk_Text_View (Widget)));
         else
            Clipboard.Last_Widget := null;
         end if;
      end if;
   end Paste_Clipboard;

   ------------------------------
   -- Paste_Previous_Clipboard --
   ------------------------------

   procedure Paste_Previous_Clipboard
     (Clipboard : access Clipboard_Record;
      Widget    : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      Buffer      : Gtk_Text_Buffer;
      Result      : Boolean;
      Iter, Iter2 : Gtk_Text_Iter;
   begin
      if Clipboard.Last_Widget = null then
         return;
      end if;

      --  If the position is not the same as at the end of the previous paste,
      --  do nothing

      if Widget.all in Gtk_Editable_Record'Class then
         if Clipboard.Last_Position /=
           Integer (Get_Position (Gtk_Editable (Widget)))
         then
            Clipboard.Last_Widget := null;
            Trace (Me, "Paste Previous not at the same position");
            return;
         end if;

      elsif Widget.all in Gtk_Text_View_Record'Class then
         Buffer := Get_Buffer (Gtk_Text_View (Widget));
         Get_Iter_At_Mark (Buffer, Iter, Get_Insert (Buffer));
         if Clipboard.Last_Position /= Integer (Get_Offset (Iter)) then
            Trace (Me, "Paste Previous not at the same position");
            Clipboard.Last_Widget := null;
            return;
         end if;
      else
         return;
      end if;

      --  Remove the previous insert

      if Widget.all in Gtk_Editable_Record'Class then
         Delete_Text
           (Gtk_Editable (Widget),
            Start_Pos => Gint (Clipboard.Last_Position
              - Clipboard.Last_Length - 1),
            End_Pos   => Gint (Clipboard.Last_Position));
      else
         Copy (Source => Iter, Dest => Iter2);
         Forward_Chars (Iter, -Gint (Clipboard.Last_Length), Result);
         Delete (Buffer, Iter, Iter2);
      end if;

      --  Prepare the next paste.
      --  If we have just pasted the system's clipboard, do not move the
      --  current position

      if not Clipboard.Last_Is_From_System then
         Clipboard.Last_Paste := Clipboard.Last_Paste + 1;
      end if;

      if Clipboard.Last_Paste > Clipboard.List'Last
        or else Clipboard.Last_Paste < Clipboard.List'First
        or else Clipboard.List (Clipboard.Last_Paste) = null
      then
         Clipboard.Last_Paste := Clipboard.List'First;
      end if;

      Clipboard.Last_Is_From_System := False;

      if Clipboard.List (Clipboard.Last_Paste) /= null then
         Set_Text (Gtk.Clipboard.Get,
                   Clipboard.List (Clipboard.Last_Paste).all);
         Clipboard.Last_Length := Clipboard.List (Clipboard.Last_Paste)'Length;

         --  Paste the new contents
         if Widget.all in Gtk_Editable_Record'Class then
            Paste_Clipboard (Gtk_Editable (Widget));
            Clipboard.Last_Position :=
              Integer (Get_Position (Gtk_Editable (Widget)));
         else
            Paste_Clipboard
              (Buffer, Gtk.Clipboard.Get,
               Default_Editable => Get_Editable (Gtk_Text_View (Widget)));
            Get_Iter_At_Mark (Buffer, Iter, Get_Insert (Buffer));
            Clipboard.Last_Position := Integer (Get_Offset (Iter));
         end if;
      end if;

      Run_Hook (Clipboard.Kernel, Clipboard_Changed_Hook);
   end Paste_Previous_Clipboard;

   -----------------
   -- Get_Content --
   -----------------

   function Get_Content
     (Clipboard : access Clipboard_Record) return Selection_List
   is
   begin
      return Clipboard.List.all;
   end Get_Content;

   --------------------
   -- Get_Last_Paste --
   --------------------

   function Get_Last_Paste
     (Clipboard : access Clipboard_Record) return Integer
   is
   begin
      return Clipboard.Last_Paste;
   end Get_Last_Paste;

   ---------------------
   -- Merge_Clipboard --
   ---------------------

   procedure Merge_Clipboard
     (Clipboard : access Clipboard_Record;
      Index1, Index2 : Natural)
   is
      Str : String_Access;
   begin
      if Index1 in Clipboard.List'Range
        and then Index2 in Clipboard.List'Range
        and then Clipboard.List (Index1) /= null
        and then Clipboard.List (Index2) /= null
      then
         Str := new String'(Clipboard.List (Index2).all
                            & Clipboard.List (Index1).all);
         Free (Clipboard.List (Index1));
         Clipboard.List (Index1) := Str;

         Free (Clipboard.List (Index2));
         if Index2 /= Clipboard.List'Last then
            Clipboard.List (Index2 .. Clipboard.List'Last - 1) :=
              (Clipboard.List (Index2 + 1 .. Clipboard.List'Last));
            Clipboard.List (Clipboard.List'Last) := null;
         end if;

         Clipboard.Last_Paste := Index1;
         Run_Hook (Clipboard.Kernel, Clipboard_Changed_Hook);
      end if;
   end Merge_Clipboard;

end GPS.Kernel.Clipboard;
