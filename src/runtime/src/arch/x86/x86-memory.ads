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

with Interfaces;

-------------------------------------------------------------------------------
--  SYSTEM.X86.MEMORY
--
--  Purpose:
--    This package contains code and defintions for implementing and working
--    with memory on the x86 platform.
-------------------------------------------------------------------------------
package x86.Memory is
   pragma Preelaborate (x86.Memory);

   type Byte_Array is array (Natural range <>)
     of aliased Interfaces.Unsigned_8;

   ----------------------------------------------------------------------------
   --  Copy
   --
   --  Purpose:
   --    Generic memcpy implementation.
   --    This is reuired by the runtime for default initialisation of
   --    package variables.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Copy (
     Source : System.Address;
     Dest   : System.Address;
     Count  : Integer
   ) return System.Address
   with Export,
     Convention    => C,
     External_Name => "memcpy";

end x86.Memory;
