------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2018-2019, AdaCore                     --
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

with Ada.Containers.Doubly_Linked_Lists;

with GNATCOLL.Arg_Lists;
with GNATCOLL.VFS;

with GPS.Kernel;

with LSP.Clients.Response_Handlers;
with LSP.Clients;
with LSP.Messages;
with LSP.Types;

package GPS.LSP_Clients is

   type LSP_Client
     (Kernel : not null access GPS.Kernel.Kernel_Handle_Record'Class)
       is limited new LSP.Clients.Client with private;
   --  Client represents a connect to LSP server for some language

   type LSP_Client_Access is access all LSP_Client;

   not overriding procedure Start
     (Self : aliased in out LSP_Client;
      Cmd  : GNATCOLL.Arg_Lists.Arg_List);
   --  Use given command line to start LSP server

   not overriding procedure Open_File
     (Self : in out LSP_Client;
      File : GNATCOLL.VFS.Virtual_File);
   --  Send open file notification to LSP server

private

   type Response_Handler (Client : access LSP_Client) is
     new LSP.Clients.Response_Handlers.Response_Handler with null record;

   overriding procedure Initialize_Response
     (Self     : not null access Response_Handler;
      Request  : LSP.Types.LSP_Number;
      Response : LSP.Messages.Initialize_Response);

   type Command_Kinds is (Open_File);

   type Command (Kind : Command_Kinds := Command_Kinds'First) is record
      case Kind is
         when Open_File =>
            File : GNATCOLL.VFS.Virtual_File;
      end case;
   end record;

   package Command_Lists is new Ada.Containers.Doubly_Linked_Lists (Command);
   --  Until the server has responded to the initialize request, the client
   --  must not send any additional requests or notifications to the server.

   type LSP_Client
     (Kernel : not null access GPS.Kernel.Kernel_Handle_Record'Class) is
       limited new LSP.Clients.Client
   with record
      Is_Ready : Boolean := False;  --  If server is initialized
      Response_Handler : aliased LSP_Clients.Response_Handler
        (LSP_Client'Unchecked_Access);
      Commands : Command_Lists.List;  --  Command Queue
      Server_Capabilities : LSP.Messages.ServerCapabilities;
   end record;

   overriding procedure On_Error
     (Self  : in out LSP_Client;
      Error : String);

end GPS.LSP_Clients;
