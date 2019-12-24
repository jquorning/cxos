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

with Cxos.Memory.Map;

package body Cxos.Memory.Paging is
   ----------------------------------------------------------------------------
   --  Create_New_Page_Directory
   --
   --  Purpose:
   --    Allocates and initialises a new page directory, placing the address
   --    of the newly allocated directory in the provided parameter.
   ----------------------------------------------------------------------------
   function Create_New_Page_Directory (
     Page_Directory_Addr : out System.Address
   ) return Process_Result is
      use x86.Memory.Paging;

      --  The address of the newly allocated page frame, if applicable.
      Allocated_Addr   : System.Address;
      --  The virtual address of the mapping to the new structure.
      Dir_Virtual_Addr : System.Address;
   begin
      --  Set to null address as a default fallback.
      Page_Directory_Addr := System.Null_Address;

      --  Allocate the new page frame needed for the table.
      Allocate_New_Frame :
         declare
            --  The process result of allocating a new page frame, if needed.
            Allocate_Result : Process_Result;
         begin
            --  Allocate a page frame for the new page table.
            Allocate_Result := Cxos.Memory.Map.Allocate_Frame (Allocated_Addr);
            if Allocate_Result /= Success then
               return Frame_Allocation_Error;
            end if;
         end Allocate_New_Frame;

      --  Map the new structure into memory.
      Map_New_Structure :
         declare
            --  The result of the mapping process.
            Map_Result : Process_Result;
         begin
            Map_Result := Temporarily_Map_Page (Allocated_Addr,
              Dir_Virtual_Addr);
            if Map_Result /= Success then
               return Map_Result;
            end if;
         end Map_New_Structure;

      --  Initialise the newly allocated page directory.
      Init_Page_Directory :
         declare
            --  The new directory mapped into virtual memory.
            New_Page_Dir : Page_Directory
            with Import,
              Convention => Ada,
              Address    => Dir_Virtual_Addr;

            --  The currently loaded page directory.
            Curr_Page_Dir : Page_Directory
            with Import,
              Convention => Ada,
              Address    => To_Address (PAGE_DIR_RECURSIVE_ADDR);

            --  The result of initialising the page table.
            Init_Result : Process_Result;
         begin
            Init_Result := Initialise_Page_Directory (New_Page_Dir);
            if Init_Result /= Success then
               return Init_Result;
            end if;

            --  Copy the kernel memory space from the currently loaded
            --  address space into the newly created page directory.
            for Dir_Entry_Idx in Integer range 768 .. 1023 loop
               New_Page_Dir (Dir_Entry_Idx) := Curr_Page_Dir (Dir_Entry_Idx);
            end loop;
         end Init_Page_Directory;

      --  Free the temporarily mapped structure.
      Free_Temporary_Mapping :
         declare
            --  The result of the freeing process.
            Free_Result : Process_Result;
         begin
            Free_Result := Free_Temporary_Page_Mapping (Dir_Virtual_Addr);
            if Free_Result /= Success then
               return Free_Result;
            end if;
         end Free_Temporary_Mapping;

      Page_Directory_Addr := Allocated_Addr;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Create_New_Page_Directory;

   ----------------------------------------------------------------------------
   --  Find_Free_Kernel_Page
   ----------------------------------------------------------------------------
   function Find_Free_Kernel_Page (
     Table_Index : out Natural;
     Page_Index  : out Natural
   ) return Process_Result is
      use x86.Memory.Paging;

      --  The currently loaded kernel page_directory.
      Kernel_Page_Dir : Page_Directory
      with Import,
        Convention => Ada,
        Address    => To_Address (PAGE_DIR_RECURSIVE_ADDR);

      --  The address of each page table.
      --  This will be set to the address that each page table being checked
      --  is recursively mapped into memory.
      Table_Addr : System.Address;

      --  The result of internal processes.
      Result : Process_Result;
   begin
      --  Loop over every page in the directory, checking only the entries
      --  which are marked as present.
      --  The last two directory entries are ignored, since these are
      --  reserved for special functionality.
      for Dir_Entry_Idx in Integer range 768 .. 1021 loop
         if Kernel_Page_Dir (Dir_Entry_Idx).Present then
            --  Get the address of this page table in memory.
            Result := Get_Page_Table_Mapped_Address (Dir_Entry_Idx,
              Table_Addr);
            if Result /= Success then
               return Unhandled_Exception;
            end if;

            --  Check the page table for non-present entries, denoting a free
            --  page frame.
            Check_Page_Table :
               declare
                  --  The page table to check.
                  Kernel_Table : constant Page_Table
                  with Import,
                    Convention => Ada,
                    Address    => Table_Addr;
               begin
                  --  Check each frame entry in the page table.
                  for Frame_Idx in Integer range 0 .. 1023 loop
                     if Kernel_Table (Frame_Idx).Present = False then
                        Table_Index := Dir_Entry_Idx;
                        Page_Index  := Frame_Idx;

                        return Success;
                     end if;
                  end loop;
               end Check_Page_Table;
         end if;
      end loop;

      --  If we have not found an address, set the output to NULL and return
      --  that there are no free frames.
      Table_Index := 0;
      Page_Index  := 0;

      return No_Free_Frames;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Find_Free_Kernel_Page;

   ----------------------------------------------------------------------------
   --  Free_Temporary_Page_Mapping
   ----------------------------------------------------------------------------
   function Free_Temporary_Page_Mapping (
     Virtual_Addr : System.Address
   ) return Process_Result is
      use x86.Memory.Paging;

      --  The currently loaded kernel page_directory.
      Temp_Page_Table : Page_Table
      with Import,
        Convention => Ada,
        Address    => To_Address (TEMP_TABLE_RECURSIVE_ADDR);

      --  The index into the table of the entry to unmap.
      Table_Idx : Natural;
   begin
      --  Ensure that the provided virtual address is within the temp table.
      Check_Virtual_Address :
         begin
            if (To_Integer (Virtual_Addr) < TEMP_TABLE_BASE_ADDR) or
              (To_Integer (Virtual_Addr) > TEMP_TABLE_BASE_ADDR + 16#400000#)
            then
               --  Return Invalid_Argument in the instance that the provided
               --  address is not mapped in the temporary table.
               return Invalid_Argument;
            end if;
         end Check_Virtual_Address;

      --  Get the index into the page table, based upon the provided virtual
      --  address.
      Get_Table_Mapping :
         begin
            --  Subtract the base of the temp table address from the provided
            --  virtual address, then divide it by the size of a page frame.
            Table_Idx := Natural (To_Integer (Virtual_Addr) -
              TEMP_TABLE_BASE_ADDR) / 16#1000#;
         end Get_Table_Mapping;

      --  Set the table index to be non-present.
      Temp_Page_Table (Table_Idx).Present := False;

      --  Reload the TLB to free the mapping.
      Flush_Tlb;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Free_Temporary_Page_Mapping;

   ----------------------------------------------------------------------------
   --  Get_Page_Table_Mapped_Address
   ----------------------------------------------------------------------------
   function Get_Page_Table_Mapped_Address (
     Table_Index :     Natural;
     Mapped_Addr : out System.Address
   ) return Process_Result is
      --  The offset from the base mapping offset.
      Table_Map_Offset : Integer_Address := 0;
   begin
      Calculate_Mapped_Address :
         begin
            Table_Map_Offset := Integer_Address (16#1000# * Table_Index);
            Mapped_Addr := To_Address (PAGE_TABLES_BASE_ADDR
              + Table_Map_Offset);
         exception
            when Constraint_Error =>
               return Unhandled_Exception;
         end Calculate_Mapped_Address;

      return Success;
   end Get_Page_Table_Mapped_Address;

   ----------------------------------------------------------------------------
   --  Get_Page_Table_Mapped_Address
   ----------------------------------------------------------------------------
   function Get_Page_Table_Mapped_Address (
     Virtual_Addr :     System.Address;
     Mapped_Addr  : out System.Address
   ) return Process_Result is
      use x86.Memory.Paging;

      --  The index into the page directory that this virtual address
      --  is mapped at.
      Directory_Idx    : Natural;
      --  The offset from the base mapping offset.
      Table_Map_Offset : Integer_Address := 0;
      --  The result of internal processes.
      Result           : x86.Memory.Paging.Process_Result;
   begin
      --  Ensure that the provided address is properly page aligned.
      Check_Address :
         begin
            if not Check_Address_Page_Aligned (Virtual_Addr) then
               return Invalid_Non_Aligned_Address;
            end if;
         exception
            when Constraint_Error =>
               return Invalid_Non_Aligned_Address;
         end Check_Address;

      --  Get the directory index.
      Get_Directory_Idx :
         begin
            Result := Get_Page_Directory_Index (Virtual_Addr, Directory_Idx);
            if Result /= Success then
               return Unhandled_Exception;
            end if;
         exception
            when Constraint_Error =>
               return Invalid_Non_Aligned_Address;
         end Get_Directory_Idx;

      Calculate_Mapped_Address :
         begin
            Table_Map_Offset := Integer_Address (16#1000# * Directory_Idx);
            Mapped_Addr := To_Address (PAGE_TABLES_BASE_ADDR
              + Table_Map_Offset);
         exception
            when Constraint_Error =>
               return Unhandled_Exception;
         end Calculate_Mapped_Address;

      return Success;
   end Get_Page_Table_Mapped_Address;

   ----------------------------------------------------------------------------
   --  Initialise_Page_Directory
   ----------------------------------------------------------------------------
   function Initialise_Page_Directory (
     Page_Dir : in out x86.Memory.Paging.Page_Directory
   ) return Process_Result is
      use x86.Memory.Paging;
   begin
      --  Iterate over all 1024 directory entries.
      for Idx in 0 .. 1023 loop
         --  Initialise the individual entry.
         Initialise_Entry :
            begin
               Page_Dir (Idx).Present       := False;
               Page_Dir (Idx).Read_Write    := True;
               Page_Dir (Idx).U_S           := False;
               Page_Dir (Idx).PWT           := False;
               Page_Dir (Idx).PCD           := False;
               Page_Dir (Idx).A             := False;
               Page_Dir (Idx).PS            := False;
               Page_Dir (Idx).G             := False;
               Page_Dir (Idx).Table_Address :=
                 Convert_To_Page_Aligned_Address (System.Null_Address);
            exception
               when Constraint_Error =>
                  return Invalid_Value;
            end Initialise_Entry;
      end loop;

      return Success;
   end Initialise_Page_Directory;

   ----------------------------------------------------------------------------
   --  Initialise_Page_Table
   ----------------------------------------------------------------------------
   function Initialise_Page_Table (
     Table : in out x86.Memory.Paging.Page_Table
   ) return Process_Result is
      use x86.Memory.Paging;
   begin
      for Idx in 0 .. 1023 loop
         Initialise_Entry :
            begin
               Table (Idx).Present      := False;
               Table (Idx).Read_Write   := True;
               Table (Idx).U_S          := False;
               Table (Idx).PWT          := False;
               Table (Idx).PCD          := False;
               Table (Idx).A            := False;
               Table (Idx).Page_Address :=
                 Convert_To_Page_Aligned_Address (System.Null_Address);
            exception
               when Constraint_Error =>
                  return Invalid_Value;
            end Initialise_Entry;
      end loop;

      return Success;
   end Initialise_Page_Table;

   ----------------------------------------------------------------------------
   --  Temporarily_Map_Page
   ----------------------------------------------------------------------------
   function Temporarily_Map_Page (
     Frame_Addr   :     System.Address;
     Virtual_Addr : out System.Address
   ) return Process_Result is
      use x86.Memory.Paging;

      --  The currently loaded kernel page_directory.
      Temp_Page_Table : Page_Table
      with Import,
        Convention => Ada,
        Address    => To_Address (TEMP_TABLE_RECURSIVE_ADDR);
   begin
      --  Set the output address to null as a default fallback.
      Virtual_Addr := System.Null_Address;

      --  Check each frame entry in the page table to find a free entry.
      for Frame_Idx in Integer range 0 .. 1023 loop
         --  If a non-present frame is found, map that.
         if Temp_Page_Table (Frame_Idx).Present = False then
            Temp_Page_Table (Frame_Idx).Present      := True;
            Temp_Page_Table (Frame_Idx).Read_Write   := True;
            Temp_Page_Table (Frame_Idx).Page_Address :=
              Convert_To_Page_Aligned_Address (Frame_Addr);

            --  Reload the TLB to set up the new mapping.
            Flush_Tlb;

            --  Set the output parameter to the newly mapped address.
            Virtual_Addr := To_Address (TEMP_TABLE_BASE_ADDR +
              Integer_Address (Frame_Idx * 16#1000#));

            return Success;
         end if;
      end loop;

      --  If we iterate through the entire table and cannot find a free
      --  frame, return this result.
      return No_Free_Frames;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Temporarily_Map_Page;

end Cxos.Memory.Paging;
