------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                           Make_Suite_Window_Pkg                          --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                            $Revision$
--                                                                          --
--                Copyright (C) 2001 Ada Core Technologies, Inc.            --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with GNAT;  see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- GNAT is maintained by Ada Core Technologies Inc (http://www.gnat.com).   --
--                                                                          --
------------------------------------------------------------------------------

with Gtk; use Gtk;
with Gtk.Widget;      use Gtk.Widget;
with Gtk.Enums;       use Gtk.Enums;
with Gtk.Clist;       use Gtk.Clist;
with Gtkada.Handlers; use Gtkada.Handlers;
with Callbacks_Aunit_Gui; use Callbacks_Aunit_Gui;
with Aunit_Gui_Intl; use Aunit_Gui_Intl;
with Make_Suite_Window_Pkg.Callbacks; use Make_Suite_Window_Pkg.Callbacks;

package body Make_Suite_Window_Pkg is
   --  "AUnit_Make_Suite" main window definition.  Mostly generated by
   --  Glade

procedure Gtk_New (Make_Suite_Window : out Make_Suite_Window_Access) is
begin
   Make_Suite_Window := new Make_Suite_Window_Record;
   Make_Suite_Window_Pkg.Initialize (Make_Suite_Window);
end Gtk_New;

procedure Initialize (Make_Suite_Window : access Make_Suite_Window_Record'Class) is
   pragma Suppress (All_Checks);
begin
   Gtk.Window.Initialize (Make_Suite_Window, Window_Toplevel);
   Set_Title (Make_Suite_Window, -"Make new suite");
   Set_Policy (Make_Suite_Window, False, True, False);
   Set_Position (Make_Suite_Window, Win_Pos_None);
   Set_Modal (Make_Suite_Window, False);
   Set_Default_Size (Make_Suite_Window, 500, 300);

   Return_Callback.Connect
     (Make_Suite_Window, "delete_event", On_Make_Suite_Window_Delete_Event'Access);

   Gtk_New_Vbox (Make_Suite_Window.Vbox1, False, 0);
   Add (Make_Suite_Window, Make_Suite_Window.Vbox1);

   Gtk_New_Hbox (Make_Suite_Window.Hbox1, False, 0);
   Pack_Start (Make_Suite_Window.Vbox1, Make_Suite_Window.Hbox1, False, True, 3);

   Gtk_New_Vbox (Make_Suite_Window.Vbox2, True, 0);
   Pack_Start (Make_Suite_Window.Hbox1, Make_Suite_Window.Vbox2, False, False, 5);

   Gtk_New (Make_Suite_Window.Label1, -("Suite name :"));
   Set_Alignment (Make_Suite_Window.Label1, 1.0, 0.5);
   Set_Padding (Make_Suite_Window.Label1, 0, 0);
   Set_Justify (Make_Suite_Window.Label1, Justify_Center);
   Set_Line_Wrap (Make_Suite_Window.Label1, False);
   Pack_Start (Make_Suite_Window.Vbox2, Make_Suite_Window.Label1, False, False, 0);

   Gtk_New_Vbox (Make_Suite_Window.Vbox3, True, 0);
   Pack_Start (Make_Suite_Window.Hbox1, Make_Suite_Window.Vbox3, True, True, 3);

   Gtk_New (Make_Suite_Window.Name_Entry);
   Set_Editable (Make_Suite_Window.Name_Entry, True);
   Set_Max_Length (Make_Suite_Window.Name_Entry, 0);
   Set_Text (Make_Suite_Window.Name_Entry, -"New_Suite");
   Set_Visibility (Make_Suite_Window.Name_Entry, True);
   Pack_Start (Make_Suite_Window.Vbox3, Make_Suite_Window.Name_Entry, False, False, 1);

   Gtk_New_Hbox (Make_Suite_Window.Hbox8, False, 0);
   Pack_Start (Make_Suite_Window.Vbox1, Make_Suite_Window.Hbox8, True, True, 3);

   Gtk_New_Vbox (Make_Suite_Window.Vbox4, False, 0);
   Pack_Start (Make_Suite_Window.Hbox8, Make_Suite_Window.Vbox4, True, True, 3);

   Gtk_New (Make_Suite_Window.Label2, -("The following tests will be added to the new suite :"));
   Set_Alignment (Make_Suite_Window.Label2, 0.0, 0.5);
   Set_Padding (Make_Suite_Window.Label2, 6, 0);
   Set_Justify (Make_Suite_Window.Label2, Justify_Center);
   Set_Line_Wrap (Make_Suite_Window.Label2, False);
   Pack_Start (Make_Suite_Window.Vbox4, Make_Suite_Window.Label2, False, False, 0);

   Gtk_New_Hbox (Make_Suite_Window.Hbox2, False, 0);
   Pack_Start (Make_Suite_Window.Vbox4, Make_Suite_Window.Hbox2, True, True, 0);

   Gtk_New (Make_Suite_Window.Scrolledwindow2);
   Set_Policy (Make_Suite_Window.Scrolledwindow2, Policy_Automatic, Policy_Automatic);
   Pack_Start (Make_Suite_Window.Hbox2, Make_Suite_Window.Scrolledwindow2, True, True, 3);

   Gtk_New (Make_Suite_Window.Test_List, 2);
   Set_Selection_Mode (Make_Suite_Window.Test_List, Selection_Single);
   Set_Shadow_Type (Make_Suite_Window.Test_List, Shadow_In);
   Set_Show_Titles (Make_Suite_Window.Test_List, False);
   Set_Column_Width (Make_Suite_Window.Test_List, 0, 80);
   Set_Column_Width (Make_Suite_Window.Test_List, 1, 80);
   Set_Row_Height (Make_Suite_Window.Test_List, 15);
   Set_Column_Auto_Resize (Make_Suite_Window.Test_List, 0, True);
   Add (Make_Suite_Window.Scrolledwindow2, Make_Suite_Window.Test_List);

   Gtk_New (Make_Suite_Window.Label5, -("label5"));
   Set_Alignment (Make_Suite_Window.Label5, 0.5, 0.5);
   Set_Padding (Make_Suite_Window.Label5, 0, 0);
   Set_Justify (Make_Suite_Window.Label5, Justify_Center);
   Set_Line_Wrap (Make_Suite_Window.Label5, False);
   Set_Column_Widget (Make_Suite_Window.Test_List, 0, Make_Suite_Window.Label5);

   Gtk_New (Make_Suite_Window.Label6, -("label6"));
   Set_Alignment (Make_Suite_Window.Label6, 0.5, 0.5);
   Set_Padding (Make_Suite_Window.Label6, 0, 0);
   Set_Justify (Make_Suite_Window.Label6, Justify_Center);
   Set_Line_Wrap (Make_Suite_Window.Label6, False);
   Set_Column_Widget (Make_Suite_Window.Test_List, 1, Make_Suite_Window.Label6);

   Gtk_New (Make_Suite_Window.Label7, -("label7"));
   Set_Alignment (Make_Suite_Window.Label7, 0.5, 0.5);
   Set_Padding (Make_Suite_Window.Label7, 0, 0);
   Set_Justify (Make_Suite_Window.Label7, Justify_Center);
   Set_Line_Wrap (Make_Suite_Window.Label7, False);
   Set_Column_Widget (Make_Suite_Window.Test_List, 2, Make_Suite_Window.Label7);

   Gtk_New (Make_Suite_Window.Vbuttonbox1);
   Set_Spacing (Make_Suite_Window.Vbuttonbox1, 10);
   Set_Layout (Make_Suite_Window.Vbuttonbox1, Buttonbox_Spread);
   Set_Child_Size (Make_Suite_Window.Vbuttonbox1, 85, 27);
   Set_Child_Ipadding (Make_Suite_Window.Vbuttonbox1, 7, 0);
   Pack_Start (Make_Suite_Window.Hbox2, Make_Suite_Window.Vbuttonbox1, False, True, 3);

   Gtk_New (Make_Suite_Window.Add, -"Add");
   Set_Relief (Make_Suite_Window.Add, Relief_Normal);
   Set_Flags (Make_Suite_Window.Add, Can_Default);
   Button_Callback.Connect
     (Make_Suite_Window.Add, "clicked",
      Button_Callback.To_Marshaller (On_Add_Clicked'Access));
   Add (Make_Suite_Window.Vbuttonbox1, Make_Suite_Window.Add);

   Gtk_New (Make_Suite_Window.Remove, -"Remove");
   Set_Relief (Make_Suite_Window.Remove, Relief_Normal);
   Set_Flags (Make_Suite_Window.Remove, Can_Default);
   Button_Callback.Connect
     (Make_Suite_Window.Remove, "clicked",
      Button_Callback.To_Marshaller (On_Remove_Clicked'Access));
   Add (Make_Suite_Window.Vbuttonbox1, Make_Suite_Window.Remove);

   Gtk_New (Make_Suite_Window.Hbuttonbox1);
   Set_Spacing (Make_Suite_Window.Hbuttonbox1, 30);
   Set_Layout (Make_Suite_Window.Hbuttonbox1, Buttonbox_Spread);
   Set_Child_Size (Make_Suite_Window.Hbuttonbox1, 85, 27);
   Set_Child_Ipadding (Make_Suite_Window.Hbuttonbox1, 7, 0);
   Pack_Start (Make_Suite_Window.Vbox1, Make_Suite_Window.Hbuttonbox1, False, False, 3);

   Gtk_New (Make_Suite_Window.Ok, -"OK");
   Set_Relief (Make_Suite_Window.Ok, Relief_Normal);
   Set_Flags (Make_Suite_Window.Ok, Can_Default);
   Button_Callback.Connect
     (Make_Suite_Window.Ok, "clicked",
      Button_Callback.To_Marshaller (On_Ok_Clicked'Access));
   Add (Make_Suite_Window.Hbuttonbox1, Make_Suite_Window.Ok);

   Gtk_New (Make_Suite_Window.Cancel, -"Cancel");
   Set_Relief (Make_Suite_Window.Cancel, Relief_Normal);
   Set_Flags (Make_Suite_Window.Cancel, Can_Default);
   Button_Callback.Connect
     (Make_Suite_Window.Cancel, "clicked",
      Button_Callback.To_Marshaller (On_Cancel_Clicked'Access));
   Add (Make_Suite_Window.Hbuttonbox1, Make_Suite_Window.Cancel);

   Gtk_New (Make_Suite_Window.Help, -"Help");
   Set_Relief (Make_Suite_Window.Help, Relief_Normal);
   Set_Flags (Make_Suite_Window.Help, Can_Default);
   Button_Callback.Connect
     (Make_Suite_Window.Help, "clicked",
      Button_Callback.To_Marshaller (On_Help_Clicked'Access));
   Add (Make_Suite_Window.Hbuttonbox1, Make_Suite_Window.Help);

end Initialize;

end Make_Suite_Window_Pkg;
