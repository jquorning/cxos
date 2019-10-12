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

with System;

-------------------------------------------------------------------------------
--  SYSTEM.X86.PAGING
--
--  Purpose:
--    This package contains code and defintions for implementing and working
--    with paging on the x86 platform.
-------------------------------------------------------------------------------
package x86.Paging is
   pragma Preelaborate (x86.Paging);

   ----------------------------------------------------------------------------
   --  Initialise
   --
   --  Purpose:
   --    This procedure iniitalises paging on the processor.
   --    This initialises the page directory and table structures and loads
   --    their location into the processor.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   procedure Initialise;

   ----------------------------------------------------------------------------
   --  Finalise
   --
   --  Purpose:
   --    This procedure finalises the loading of the page directory structures
   --    into the processor's control registers.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   procedure Finalise
   with Import,
     Convention    => Assembler,
     External_Name => "__paging_load";

private
   ----------------------------------------------------------------------------
   --  Type to hold the address of a page table.
   --  Used by a Page Directory Entry.
   ----------------------------------------------------------------------------
   type Page_Table_Address is mod 2 ** 20;

   ----------------------------------------------------------------------------
   --  Type to hold the physical address of a page.
   --  Used by a Page Table Entry.
   ----------------------------------------------------------------------------
   type Physical_Page_Address is mod 2 ** 20;

   ----------------------------------------------------------------------------
   --  Page Directory Entry type.
   ----------------------------------------------------------------------------
   type Page_Directory_Entry is
      record
         Present       : Boolean;
         Read_Write    : Boolean;
         U_S           : Boolean;
         PWT           : Boolean;
         PCD           : Boolean;
         A             : Boolean;
         PS            : Boolean;
         Table_Address : Page_Table_Address;
      end record
   with Size => 32;
   for Page_Directory_Entry use
      record
         Present       at 0 range 0 .. 0;
         Read_Write    at 0 range 1 .. 1;
         U_S           at 0 range 2 .. 2;
         PWT           at 0 range 3 .. 3;
         PCD           at 0 range 4 .. 4;
         A             at 0 range 5 .. 5;
         PS            at 0 range 7 .. 7;
         Table_Address at 0 range 12 .. 31;
      end record;

   ----------------------------------------------------------------------------
   --  Page Table Entry type.
   ----------------------------------------------------------------------------
   type Page_Table_Entry is
      record
         Present      : Boolean;
         Read_Write   : Boolean;
         U_S          : Boolean;
         PWT          : Boolean;
         PCD          : Boolean;
         A            : Boolean;
         D            : Boolean;
         PAT          : Boolean;
         G            : Boolean;
         Page_Address : Physical_Page_Address;
      end record
   with Size => 32;
   for Page_Table_Entry use
      record
         Present      at 0 range 0 .. 0;
         Read_Write   at 0 range 1 .. 1;
         U_S          at 0 range 2 .. 2;
         PWT          at 0 range 3 .. 3;
         PCD          at 0 range 4 .. 4;
         A            at 0 range 5 .. 5;
         D            at 0 range 6 .. 6;
         PAT          at 0 range 7 .. 7;
         G            at 0 range 8 .. 8;
         Page_Address at 0 range 12 .. 31;
      end record;

   ----------------------------------------------------------------------------
   --  Address_To_Page_Table_Address
   --
   --  Purpose:
   --    This function converts a System Address to the 20bit 4kb aligned
   --    addresses expected by the page table entities.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Address_To_Page_Table_Address (
     Addr : System.Address
   ) return Page_Table_Address
   with Pure_Function;

   ----------------------------------------------------------------------------
   --  Individual Page Table type.
   --  This is an array of 1024 indiviudal Page Table Entries.
   ----------------------------------------------------------------------------
   type Page_Table is array (Natural range 0 .. 1023) of Page_Table_Entry;

   ----------------------------------------------------------------------------
   --  Page Table array type.
   --  This is an array of 1024 indiviudal Page Tables. This is used to
   --  interface with the externally declared block of memory reserved for
   --  implementing the page tables.
   ----------------------------------------------------------------------------
   type Page_Table_Array is array (Natural range 0 .. 1023) of Page_Table;

   ----------------------------------------------------------------------------
   --  Page Directory array.
   --  This is used to implement the main page table directory.
   ----------------------------------------------------------------------------
   type Page_Directory_Array is array (Natural range 0 .. 1023)
     of Page_Directory_Entry;

   ----------------------------------------------------------------------------
   --  System Page Directory.
   --  This is the main directory containing all of the page tables.
   ----------------------------------------------------------------------------
   Page_Directory : Page_Directory_Array
   with Alignment  => 4,
     Export,
     Convention    => Assembler,
     External_Name => "page_directory_pointer",
     Volatile;
   ----------------------------------------------------------------------------
   --  The System's Page Tables.
   --  This is implemented by reserving space in the linker script, which we
   --  treat as an array of 1024 page tables.
   ----------------------------------------------------------------------------
   Page_Tables : Page_Table_Array
   with Import,
     Convention    => Assembler,
     External_Name => "page_tables_start",
     Volatile;

   ----------------------------------------------------------------------------
   --  The pointer to the Page Directory structure.
   ----------------------------------------------------------------------------
   Page_Directory_Ptr : System.Address
   with Export,
     Convention    => Assembler,
     External_Name => "kkkk",
     Volatile;

end x86.Paging;