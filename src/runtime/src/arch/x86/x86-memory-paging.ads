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
--  X86.MEMORY.PAGING
--
--  Purpose:
--    This package contains code and defintions for implementing and working
--    with paging on the x86 platform.
-------------------------------------------------------------------------------
package x86.Memory.Paging is
   pragma Preelaborate;

   ----------------------------------------------------------------------------
   --  Type to hold a 20bit address.
   --  These are truncated 32bit addresses that are assumed to be 4K aligned,
   --  as such there is no need to hold the lower-order 12bits.
   ----------------------------------------------------------------------------
   type Page_Aligned_Address is mod 2 ** 20;

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
         Reserved      : Boolean := False;
         PS            : Boolean;
         G             : Boolean;
         Avail         : Boolean := False;
         Table_Address : Page_Aligned_Address;
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
         Reserved      at 0 range 6 .. 6;
         PS            at 0 range 7 .. 7;
         G             at 0 range 8 .. 8;
         Avail         at 0 range 9 .. 11;
         Table_Address at 0 range 12 .. 31;
      end record;

   ----------------------------------------------------------------------------
   --  Page Frame type.
   ----------------------------------------------------------------------------
   type Page_Frame is
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
         Page_Address : Page_Aligned_Address;
      end record
   with Size => 32;
   for Page_Frame use
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
   --  Convert_To_Page_Aligned_Address
   --
   --  Purpose:
   --    This function converts a System Address to the 20bit 4kb page aligned
   --    address type expected by the page table entities.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Convert_To_Page_Aligned_Address (
     Addr : System.Address
   ) return Page_Aligned_Address
   with Pure_Function;

   ----------------------------------------------------------------------------
   --  Convert_To_System_Address
   --
   --  Purpose:
   --    This function converts a 20bit 4kb aligned address type back to a
   --    native 32bit system address.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Convert_To_System_Address (
     Addr : Page_Aligned_Address
   ) return System.Address
   with Pure_Function;

   ----------------------------------------------------------------------------
   --  Flush_Tlb
   --
   --  Purpose:
   --    Flushes and reloads the Translation Lookaside Buffer.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   procedure Flush_Tlb
   with Import,
     Convention    => Assembler,
     External_Name => "__flush_tlb";

   ----------------------------------------------------------------------------
   --  Page table/directory range type.
   ----------------------------------------------------------------------------
   subtype Paging_Index is Natural range 0 .. 1023;

   ----------------------------------------------------------------------------
   --  Individual Page Table type.
   --  This is an array of 1024 indiviudal Pages.
   ----------------------------------------------------------------------------
   type Page_Table is array (Paging_Index) of Page_Frame;

   ----------------------------------------------------------------------------
   --  Page Directory.
   --  This type represents a a page directory, an array of individual entries.
   ----------------------------------------------------------------------------
   type Page_Directory is array (Paging_Index) of Page_Directory_Entry;

   ----------------------------------------------------------------------------
   --  Check_Address_Page_Aligned
   --
   --  Purpose:
   --    Checks whether a provided address is 4K aligned, as required by the
   --    paging entity structures.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Check_Address_Page_Aligned (
     Addr : System.Address
   ) return Boolean
   with Pure_Function;

   ----------------------------------------------------------------------------
   --  Get_Page_Address
   --
   --  Purpose:
   --    This function gets the virtual address represented by a page
   --    directory and page table index combination.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Get_Page_Address (
     Table_Index : Paging_Index;
     Page_Index  : Paging_Index
   ) return System.Address
   with Pure_Function;

   ----------------------------------------------------------------------------
   --  Get_Page_Directory_Index
   --
   --  Purpose:
   --    This function gets the index of the page table in a page directory of
   --    corresponding to a particular address.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Get_Page_Directory_Index (
     Addr : System.Address
   ) return Paging_Index
   with Pure_Function;

   ----------------------------------------------------------------------------
   --  Get_Page_Table_Index
   --
   --  Purpose:
   --    This function gets the index of the page table entry in a page table
   --    corresponding to a particular address.
   --  Exceptions:
   --    None.
   ----------------------------------------------------------------------------
   function Get_Page_Table_Index (
     Addr : System.Address
   ) return Paging_Index
   with Pure_Function;

end x86.Memory.Paging;
