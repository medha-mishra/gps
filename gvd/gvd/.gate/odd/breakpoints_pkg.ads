with Gtk.Window; use Gtk.Window;
with Gtk.Box; use Gtk.Box;
with Gtk.Notebook; use Gtk.Notebook;
with Gtk.Frame; use Gtk.Frame;
with Gtk.Radio_Button; use Gtk.Radio_Button;
with Gtk.Alignment; use Gtk.Alignment;
with Gtk.Label; use Gtk.Label;
with Gtk.Combo; use Gtk.Combo;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.Adjustment; use Gtk.Adjustment;
with Gtk.Spin_Button; use Gtk.Spin_Button;
with Gtk.Check_Button; use Gtk.Check_Button;
with Gtk.Separator; use Gtk.Separator;
with Gtk.Vbutton_Box; use Gtk.Vbutton_Box;
with Gtk.Button; use Gtk.Button;
with Gtk.Object; use Gtk.Object;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.Scrolled_Window; use Gtk.Scrolled_Window;
with Gtk.Clist; use Gtk.Clist;
with Gtk.Hbutton_Box; use Gtk.Hbutton_Box;
package Breakpoints_Pkg is

   type Breakpoints_Record is new Gtk_Window_Record with record
      Vbox1 : Gtk_Vbox;
      Notebook1 : Gtk_Notebook;
      Hbox2 : Gtk_Hbox;
      Vbox2 : Gtk_Vbox;
      Frame12 : Gtk_Frame;
      Vbox15 : Gtk_Vbox;
      Location_Selected : Gtk_Radio_Button;
      Alignment5 : Gtk_Alignment;
      Hbox5 : Gtk_Hbox;
      Label61 : Gtk_Label;
      File_Combo : Gtk_Combo;
      Combo_Entry5 : Gtk_Entry;
      Label62 : Gtk_Label;
      Line_Spin : Gtk_Spin_Button;
      Subprogram_Selected : Gtk_Radio_Button;
      Alignment6 : Gtk_Alignment;
      Subprogram_Combo : Gtk_Combo;
      Entry20 : Gtk_Entry;
      Address_Selected : Gtk_Radio_Button;
      Alignment7 : Gtk_Alignment;
      Address_Combo : Gtk_Combo;
      Entry21 : Gtk_Entry;
      Regexp_Selected : Gtk_Radio_Button;
      Alignment8 : Gtk_Alignment;
      Regexp_Combo : Gtk_Combo;
      Entry22 : Gtk_Entry;
      Temporary_Location : Gtk_Check_Button;
      Vseparator1 : Gtk_Vseparator;
      Vbuttonbox2 : Gtk_Vbutton_Box;
      Add_Location : Gtk_Button;
      Advanced_Location : Gtk_Button;
      Location : Gtk_Label;
      Hbox3 : Gtk_Hbox;
      Vbox7 : Gtk_Vbox;
      Label9 : Gtk_Label;
      Watchpoint_Name : Gtk_Entry;
      Label10 : Gtk_Label;
      Watchpoint_Type : Gtk_Combo;
      Combo_Entry3 : Gtk_Entry;
      Vseparator2 : Gtk_Vseparator;
      Vbuttonbox3 : Gtk_Vbutton_Box;
      Add_Watchpoint : Gtk_Button;
      Advanced_Watchpoint : Gtk_Button;
      Watchpoint : Gtk_Label;
      Hbox4 : Gtk_Hbox;
      Vbox8 : Gtk_Vbox;
      Label11 : Gtk_Label;
      Hbox14 : Gtk_Hbox;
      Exception_Name : Gtk_Combo;
      Combo_Entry25 : Gtk_Entry;
      Load_Exception_List : Gtk_Button;
      Temporary_Exception : Gtk_Check_Button;
      Frame4 : Gtk_Frame;
      Vbox9 : Gtk_Vbox;
      Stop_Always_Exception : Gtk_Radio_Button;
      Stop_Not_Handled_Exception : Gtk_Radio_Button;
      Vseparator3 : Gtk_Vseparator;
      Vbuttonbox4 : Gtk_Vbutton_Box;
      Add_Exception : Gtk_Button;
      Advanced_Exception : Gtk_Button;
      Except : Gtk_Label;
      Frame11 : Gtk_Frame;
      Vbox16 : Gtk_Vbox;
      Label72 : Gtk_Label;
      Scrolledwindow2 : Gtk_Scrolled_Window;
      Clist1 : Gtk_Clist;
      Label15 : Gtk_Label;
      Label16 : Gtk_Label;
      Hbuttonbox8 : Gtk_Hbutton_Box;
      Remove : Gtk_Button;
      View : Gtk_Button;
      Hbuttonbox4 : Gtk_Hbutton_Box;
      Ok_Button : Gtk_Button;
   end record;
   type Breakpoints_Access is access all Breakpoints_Record'Class;

   procedure Gtk_New (Breakpoints : out Breakpoints_Access);
   procedure Initialize (Breakpoints : access Breakpoints_Record'Class);

   Breakpoints : Breakpoints_Access;

end Breakpoints_Pkg;
