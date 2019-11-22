-------------------------------------------------------------------------------
--  Copyright (c) 2019, CXOS.
--  This program is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; either version 3 of the License, or
--  (at your option) any later version.
--
--  Authors:
--     Anthony <ajxs [at] panoptic.online>
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--  CXOS
--
--  Purpose:
--    This package contains the main Kernel code.
-------------------------------------------------------------------------------
package Cxos is
   pragma Preelaborate (Cxos);

   ----------------------------------------------------------------------------
   --  Kernel Process Result type.
   --  Used to track the result of kernel processes.
   ----------------------------------------------------------------------------
   type Kernel_Process_Result is (
     Failure,
     Success
   );

   ----------------------------------------------------------------------------
   --  Initialise_Kernel
   --
   --  Purpose:
   --    Initialises the kernel.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Initialise_Kernel return Kernel_Process_Result;

   ----------------------------------------------------------------------------
   --  Main
   --
   --  Purpose:
   --    The main kernel loop.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   procedure Main
   with No_Return;

   ----------------------------------------------------------------------------
   --  Print_Splash
   --
   --  Purpose:
   --    Prints the CXOS test splash screen.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   procedure Print_Splash;
end Cxos;
