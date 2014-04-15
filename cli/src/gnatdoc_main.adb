------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2013-2014, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

--  Command line docgen utility

with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;

with GNAT.Command_Line;     use GNAT.Command_Line;
with GNAT.OS_Lib;
with GNAT.Regpat;           use GNAT.Regpat;
with GNAT.Strings;          use GNAT.Strings;

with GNATCOLL.Projects;     use GNATCOLL.Projects;
with GNATCOLL.Traces;       use GNATCOLL.Traces;
with GNATCOLL.VFS;          use GNATCOLL.VFS;

with GPS.CLI_Utils;         use GPS.CLI_Utils;
with GPS.CLI_Kernels;       use GPS.CLI_Kernels;

with GNATdoc;               use GNATdoc;
with Xref;                  use Xref;
with String_List_Utils;     use String_List_Utils;

procedure GNATdoc_Main is

   use String_List_Utils.String_List;

   Kernel : constant GPS.CLI_Kernels.CLI_Kernel :=
              new GPS.CLI_Kernels.CLI_Kernel_Record;

   Cmdline         : Command_Line_Configuration;
   Project_File    : Virtual_File;

   --  Switches

   Ignore_Files         : aliased GNAT.Strings.String_Access;
   Leading_Doc          : aliased Boolean := False;
   Regular_Expr         : aliased GNAT.Strings.String_Access;
   Process_C_Files      : aliased Boolean := False;
   Process_Bodies       : aliased Boolean := False;
   Project_Name         : aliased GNAT.Strings.String_Access;
   Backend_Name         : aliased GNAT.Strings.String_Access :=
                            new String'("html");
   Process_Private_Part : aliased Boolean := False;
   Quiet_Mode           : aliased Boolean := False;
   Enable_Warnings      : aliased Boolean := False;
   Enable_Build         : aliased Boolean := False;

   procedure Launch_Gprbuild;
   --  Launch gprbuild on the loaded project

   procedure Launch_Gnatinspect;
   --  Launch gnatinspect on the loaded project

   procedure Add_X_Switches (Args : in out String_List_Utils.String_List.List);
   --  Add the project "-Xvariable=value" to Args

   --------------------
   -- Add_X_Switches --
   --------------------

   procedure Add_X_Switches
     (Args : in out String_List_Utils.String_List.List)
   is
      procedure Local_Parse_Command_Line (Switch, Parameter, Section : String);
      --  Allow to manage every occurance of -X switch

      ------------------------
      -- Parse_Command_Line --
      ------------------------

      procedure Local_Parse_Command_Line
        (Switch, Parameter, Section : String)
      is
         pragma Unreferenced (Section);
      begin
         if Switch = "-X" then
            Append (Args, "-X" & Parameter);
         end if;
      end Local_Parse_Command_Line;
   begin
      Getopt (Cmdline, Local_Parse_Command_Line'Unrestricted_Access);
   end Add_X_Switches;

   ---------------------
   -- Launch_Gprbuild --
   ---------------------

   procedure Launch_Gprbuild is
      Result   : Integer;
      Args     : String_List_Utils.String_List.List;
      Gprbuild : GNAT.OS_Lib.String_Access;
   begin
      if not Quiet_Mode then
         Put_Line ("Rebuilding project");
      end if;

      Gprbuild := GNAT.OS_Lib.Locate_Exec_On_Path ("gprbuild");
      if Gprbuild = null then
         Gprbuild := GNAT.OS_Lib.Locate_Exec_On_Path ("gprbuild.exe");
      end if;

      if Gprbuild = null then
         Put_Line ("warning: could not find gprbuild");
         return;
      end if;

      --  Compute the arguments to launch
      Append (Args, "-U");
      Append (Args, "-k");
      Append (Args, "-q");
      Append (Args, "-P" & (+Project_File.Full_Name.all));

      Add_X_Switches (Args);

      declare
         A : GNAT.OS_Lib.Argument_List := List_To_Argument_List (Args);
      begin
         Result := GNAT.OS_Lib.Spawn
           (Program_Name => Gprbuild.all,
            Args         => A);

         if Result /= 0 then
            Put_Line ("warning: could not rebuild with:");
            Put (Gprbuild.all & " ");

            for J in A'Range loop
               Put (A (J).all & " ");
            end loop;

            New_Line;
            Put_Line ("exit code:" & Result'Img);
         end if;

         for J in A'Range loop
            GNAT.OS_Lib.Free (A (J));
         end loop;
      end;

      Free (Args);
      GNAT.OS_Lib.Free (Gprbuild);
   end Launch_Gprbuild;

   ------------------------
   -- Launch_Gnatinspect --
   ------------------------

   procedure Launch_Gnatinspect is
      Result : Integer;
      Args   : String_List_Utils.String_List.List;
      Gnatinspect : GNAT.OS_Lib.String_Access;
   begin
      if not Quiet_Mode then
         Put_Line ("Computing cross-reference information");
      end if;

      Gnatinspect := GNAT.OS_Lib.Locate_Exec_On_Path ("gnatinspect");
      if Gnatinspect = null then
         Gnatinspect := GNAT.OS_Lib.Locate_Exec_On_Path ("gnatinspect.exe");
      end if;

      if Gnatinspect = null then
         Put_Line ("warning: could not find gnatinspect");
         return;
      end if;

      --  Compute the arguments to launch
      Append (Args, "--exit");
      Append (Args, "--symlinks");
      Append (Args, "-P" & (+Project_File.Full_Name.all));
      Append (Args, "--db=" &
         (+Kernel.Databases.Xref_Database_Location.Full_Name.all));

      Add_X_Switches (Args);

      declare
         A : GNAT.OS_Lib.Argument_List := List_To_Argument_List (Args);
      begin
         Result := GNAT.OS_Lib.Spawn
           (Program_Name => Gnatinspect.all,
            Args         => A);

         if Result /= 0 then
            Put_Line ("warning: could not generate the database with:");
            Put (Gnatinspect.all & " ");

            for J in A'Range loop
               Put (A (J).all & " ");
            end loop;

            New_Line;
            Put_Line ("exit code:" & Result'Img);
         end if;

         for J in A'Range loop
            GNAT.OS_Lib.Free (A (J));
         end loop;
      end;

      Free (Args);
      GNAT.OS_Lib.Free (Gnatinspect);
   end Launch_Gnatinspect;

begin
   --  Retrieve log configuration
   GNATCOLL.Traces.Parse_Config_File;

   --  Set comand line options
   Set_Usage
     (Cmdline,
      Help => "GNATdoc command line interface");

   Define_Switch
     (Cmdline,
      Output      => Project_Name'Access,
      Switch      => "-P:",
      Long_Switch => "--project=",
      Help        => "Load the given project (mandatory)");
   Define_Switch
     (Cmdline,
      Switch       => "-X:",
      Help         => "Specify an external reference in the project");
   Define_Switch
     (Cmdline,
      Output      => Regular_Expr'Access,
      Switch      => "-R:",
      Long_Switch => "--regexp=",
      Help        => "Regular expression to select documentation comments");
   Define_Switch
     (Cmdline,
      Output       => Process_Bodies'Access,
      Switch       => "-b",
      Help         => "Process bodies");

   --  Search for the hidden switch -c in the command line arguments; if
   --  found then enable it. Done to temporarily hide the support for C/C++
   --  sources in the alpha version, but at the same time to have the ability
   --  to execute the C/C++ tests of the testsuite.

   for J in 1 .. Ada.Command_Line.Argument_Count loop
      if Ada.Command_Line.Argument (J) = "-c" then
         Define_Switch
           (Cmdline,
            Output       => Process_C_Files'Access,
            Switch       => "-c",
            Help         => "Process C/C++ files");
      end if;
   end loop;

   Define_Switch
     (Cmdline,
      Output       => Ignore_Files'Access,
      Switch       => "--ignore-files=",
      Help         => "List of files ignored by GNATdoc");
   Define_Switch
     (Cmdline,
      Output       => Leading_Doc'Access,
      Switch       => "-l",
      Help         => "Leading documentation");
   Define_Switch
     (Cmdline,
      Output       => Process_Private_Part'Access,
      Switch       => "-p",
      Help         => "Process private part of packages");
   Define_Switch
     (Cmdline,
      Output       => Quiet_Mode'Access,
      Switch       => "-q",
      Help         => "Be quiet/terse");
   Define_Switch
     (Cmdline,
      Output       => Enable_Warnings'Access,
      Switch       => "-w",
      Help         => "Enable warnings for missing documentation");
   Define_Switch
     (Cmdline,
      Output       => Enable_Build'Access,
      Switch       => "--enable-build",
      Help         => "Rebuild the project before processing it");
   Define_Switch
     (Cmdline,
      Output       => Backend_Name'Access,
      Switch       => "--output=",
      Help         => "Format of generated documentation");

   --  Initialize context
   GPS.CLI_Utils.Create_Kernel_Context (Kernel);

   --  Retrieve command line option
   begin
      GPS.CLI_Utils.Parse_Command_Line (Cmdline, Kernel);
   exception
      when GNAT.Command_Line.Invalid_Switch =>
         --  User provided some invalid switch. Just return
         return;

      when GNAT.Command_Line.Exit_From_Command_Line =>
         --  User provided -h or --help option. Just return
         return;
   end;

   --  Check project file path passed in command line
   --  Exit with message if no project file path found at all
   if not GPS.CLI_Utils.Is_Project_Path_Specified (Project_Name) then
      Put_Line ("No project file specified");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  Exit with message if path is not valid
   if not GPS.CLI_Utils.Project_File_Path_Exists (Project_Name) then
      Put_Line ("No such file: " & Project_Name.all);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Project_File := Create (+Project_Name.all);

   --  Register the package and attribute that can be used in the project
   --  files to specify a list of subprojects ignored by GNATdoc

   declare
      Result : constant String :=
        GNATCOLL.Projects.Register_New_Attribute
          (Name    => Ignored_Subprojects_Name,
           Pkg     => Pkg_Name,
           Is_List => True);
   begin
      --  Log the reported error (if any)

      if Result /= "" then
         Trace (DOCGEN_V31, Result);
      end if;
   end;

   --  Register the package and attribute that can be used in project files to
   --  specify directory to lookup image files.

   declare
      Result : constant String :=
        GNATCOLL.Projects.Register_New_Attribute
          (Name    => Image_Dir_Name,
           Pkg     => Pkg_Name);
   begin
      --  Log the reported error (if any)

      if Result /= "" then
         Trace (DOCGEN_V31, Result);
      end if;
   end;

   --  Register the package and attribute that can be used in project files to
   --  specify the documentation pattern

   declare
      Result : constant String :=
        GNATCOLL.Projects.Register_New_Attribute
          (Name    => Doc_Pattern_Name,
           Pkg     => Pkg_Name);
   begin
      --  Log the reported error (if any)

      if Result /= "" then
         Trace (DOCGEN_V31, Result);
      end if;
   end;

   --  Support symbolic links
   Kernel.Registry.Environment.Set_Trusted_Mode (False);

   --  Load project
   Kernel.Registry.Tree.Load
     (Root_Project_Path => Project_File,
      Env               => Kernel.Registry.Environment);

   --  Setup the xref databases

   Project_Changed (Kernel.Databases);
   Project_View_Changed (Kernel.Databases, Kernel.Registry.Tree);

   --  Run Gprbuild

   if Enable_Build then
      Launch_Gprbuild;
   end if;

   --  Run GNATinspect

   Launch_Gnatinspect;

   --  Run GNATdoc
   declare
      Doc_Pattern_In_Project : constant String :=
        Kernel.Registry.Tree.Root_Project.Attribute_Value
          (Attribute =>
             Attribute_Pkg_String'(Build (Pkg_Name, Doc_Pattern_Name)),
           Default => "");
      Pattern : constant String :=
        (if Regular_Expr.all = "" then Doc_Pattern_In_Project
         else Regular_Expr.all
                (Regular_Expr.all'First + 1 .. Regular_Expr.all'Last));

      --  Comments_Filter : GNAT.Expect.Pattern_Matcher_Access := null;

      Internal_Output : constant Boolean := Backend_Name.all = "test";

      Options : constant GNATdoc.Docgen_Options :=
        (Comments_Filter => (if Pattern = "" then null
                             else new Pattern_Matcher'
                                        (Compile
                                          (Pattern, Single_Line))),
         Report_Errors   => (if Enable_Warnings then Errors_And_Warnings
                                                else Errors_Only),
         Ignore_Files    => Ignore_Files,
         Leading_Doc     => Leading_Doc,
         Skip_C_Files    => not Process_C_Files,
         Tree_Output     => ((if Internal_Output then Full
                                                 else None),
                             With_Comments => False),
         Backend_Name    => To_Unbounded_String (Backend_Name.all),
         Display_Time    => Internal_Output,
         Process_Bodies  => Process_Bodies,
         Show_Private    => Process_Private_Part,
         Output_Comments => Internal_Output,
         Quiet_Mode      => Quiet_Mode);

   begin
      GNATdoc.Process_Project_Files
        (Kernel    => Kernel,
         Options   => Options,
         Project   => Kernel.Registry.Tree.Root_Project,
         Recursive => True);
   end;

   --  Destroy all
   GPS.CLI_Utils.Destroy_Kernel_Context (Kernel);

end GNATdoc_Main;
