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
   --  Create_New_Address_Space
   ----------------------------------------------------------------------------
   function Create_New_Address_Space (
     Page_Directory_Addr : out System.Address;
     Initial_EIP         :     System.Address
   ) return Process_Result is
      --  The address of the newly allocated page frame.
      Allocated_Addr    : System.Address;

      Kernel_Stack_Addr : System.Address;
      --  The temporary virtual address of the mapping to the new structure.
      --  This is used to initialise the newly allocated directory.
      Dir_Virtual_Addr  : System.Address;
      --  The result of internal processes.
      Result            : Process_Result;
   begin
      --  Set to null address as a default fallback.
      Page_Directory_Addr := System.Null_Address;

      --  Allocate a page frame for the new page directory.
      Cxos.Memory.Map.Allocate_Frames (Allocated_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      --  Temporarily map the newly allocated page frame into the current
      --  address space so that it can be initialised.
      Temporarily_Map_Page (Allocated_Addr, Dir_Virtual_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      Allocate_Kernel_Stack :
         declare
            --  The result of allocating the new page directory.
            Allocate_Result : Process_Result;
         begin
            Allocate_Result := Create_New_Kernel_Stack (Kernel_Stack_Addr,
              Initial_EIP);
            if Allocate_Result /= Success then
               return Unhandled_Exception;
            end if;
         end Allocate_Kernel_Stack;

      --  Initialise the newly allocated page directory.
      Init_Page_Directory :
         declare
            --  The currently loaded page directory.
            --  The new directory mapped into virtual memory.
            New_Page_Dir : Page_Directory
            with Import,
              Convention => Ada,
              Address    => Dir_Virtual_Addr;

            --  The currently loaded page directory.
            Curr_Page_Dir : constant Page_Directory
            with Import,
              Convention => Ada,
              Address    => To_Address (PAGE_DIR_RECURSIVE_ADDR);

            --  The physical address of the newly allocated page table that
            --  holds the kernel stack.
            Stack_Table_Addr      : System.Address;
            --  The virtual address ofthe temp mapping of the new stack table.
            Stack_Table_Virt_Addr : System.Address;

         begin
            --  Initialise the new stack page table.
            Initialise_Page_Directory (New_Page_Dir, Result);
            if Result /= Success then
               return Result;
            end if;

            --  Copy the kernel memory space from the currently loaded
            --  address space into the newly created page directory.
            for Dir_Entry_Idx in Integer range 768 .. 1023 loop
               New_Page_Dir (Dir_Entry_Idx) := Curr_Page_Dir (Dir_Entry_Idx);
            end loop;

            --  Allocate a page frame for the new page table.
            Cxos.Memory.Map.Allocate_Frames (Stack_Table_Addr, Result);
            if Result /= Success then
               return Result;
            end if;

            --  Temporarily map the newly allocated page frame into
            --  the current address space so that it can be initialised.
            Temporarily_Map_Page (Stack_Table_Addr,
              Stack_Table_Virt_Addr, Result);
            if Result /= Success then
               return Result;
            end if;

            --  Sets up the page table holding the stack.
            Setup_Stack :
               declare
                  --  The number of page frames in the kernel stack.
                  Stack_Frame_Count : Natural;
                  --  The address of each individual frame being mapped.
                  Frame_Addr        : Integer_Address;
                  --  The temp mapping of the page table into which the stack
                  --  is loaded.
                  Stack_Table : Page_Table
                  with Import,
                    Convention => Ada,
                    Address    => Stack_Table_Virt_Addr;
               begin
                  Stack_Frame_Count := KERNEL_STACK_SIZE / 16#1000#;

                  --  Initialise the new stack table.
                  Initialise_Page_Table (Stack_Table, Result);
                  if Result /= Success then
                     return Result;
                  end if;

                  --  Map each frame of the kernel stack into the new table.
                  for I in Natural range 0 .. Stack_Frame_Count loop
                     Frame_Addr := To_Integer (Kernel_Stack_Addr) +
                       Integer_Address (I * 16#1000#);

                     Stack_Table (I).Present      := True;
                     Stack_Table (I).Read_Write   := True;
                     Stack_Table (I).Page_Address :=
                       Convert_To_Page_Aligned_Address (
                       To_Address (Frame_Addr));
                  end loop;
               end Setup_Stack;

            --  Insert the newly created kernel stack page table into the
            --  new page directory.
            New_Page_Dir (1020).Table_Address :=
              Convert_To_Page_Aligned_Address (Stack_Table_Addr);

            --  Free the temporarily mapped structure.
            Free_Temporary_Page_Mapping (Stack_Table_Virt_Addr, Result);
            if Result /= Success then
               return Result;
            end if;

         end Init_Page_Directory;

      --  Free the temporarily mapped structure.
      Free_Temporary_Page_Mapping (Dir_Virtual_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      --  Set the output address to the address of the newly allocated frame.
      Page_Directory_Addr := Allocated_Addr;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Create_New_Address_Space;

   ----------------------------------------------------------------------------
   --  Create_New_Kernel_Stack
   ----------------------------------------------------------------------------
   function Create_New_Kernel_Stack (
     Stack_Addr  : out System.Address;
     Initial_EIP :     System.Address
   ) return Process_Result is
      --  Virtual address of the stack's top frame's temporary mapping into
      --  the current address space. Used during initialisation.
      Stack_Top_Virt_Addr : System.Address;
      --  Result of internal operations.
      Result : Process_Result;
   begin
      Allocate_Stack_Memory :
         declare
            --  The number of page frames that make up the kernel stack.
            Stack_Frame_Count : Natural;
            --  The address of the top stack frame.
            Stack_Top_Addr    : System.Address;
         begin
            Stack_Frame_Count := KERNEL_STACK_SIZE / 16#1000#;

            --  Allocate page frames for the new stack frame.
            Cxos.Memory.Map.Allocate_Frames (Stack_Addr, Result,
              Stack_Frame_Count);
            if Result /= Success then
               return Result;
            end if;

            Stack_Top_Addr := To_Address (To_Integer (Stack_Addr) +
              (KERNEL_STACK_SIZE - 16#1000#));

            --  Stack_Top_Addr := Stack_Addr;

            --  Temporarily map the newly allocated stack into the current
            --  address space.
            Temporarily_Map_Page (Stack_Top_Addr,
              Stack_Top_Virt_Addr, Result);
            if Result /= Success then
               return Result;
            end if;

         end Allocate_Stack_Memory;

      --  Initialise the kernel stack.
      --  Sets the initial stack EIP.
      Initialise_Kernel_Stack :
         declare
            --  Stack frame type.
            type Stack_Frame is
              array (Natural range 1 .. 1024) of System.Address;

            New_Kernel_Stack : Stack_Frame
            with Import,
              Address => Stack_Top_Virt_Addr;
         begin
            --  Set the top of the stack frame to the initial EIP.
            New_Kernel_Stack (1023) := Initial_EIP;
         end Initialise_Kernel_Stack;

      --  Free the temporarily mapped structure.
      Free_Temporary_Page_Mapping (Stack_Top_Virt_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Create_New_Kernel_Stack;

   ----------------------------------------------------------------------------
   --  Create_Page_Table
   ----------------------------------------------------------------------------
   function Create_Page_Table (
     Page_Table_Addr : out System.Address
   ) return Process_Result is
      --  The address of the newly allocated page frame.
      Allocated_Addr     : System.Address;
      --  The virtual address of the mapping to the new structure.
      Table_Virtual_Addr : System.Address;
      --  The result of internal processes.
      Result             : Process_Result;
   begin
      --  Set to null address as a default fallback.
      Page_Table_Addr := System.Null_Address;

      --  Allocate a page frame for the new page table.
      Cxos.Memory.Map.Allocate_Frames (Allocated_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      --  Temporarily map the new structure into the current address space.
      Temporarily_Map_Page (Allocated_Addr, Table_Virtual_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      --  Initialise the newly allocated page table.
      Init_Page_Table :
         declare
            --  The new table mapped into virtual memory.
            New_Page_Table : Page_Table
            with Import,
              Convention => Ada,
              Address    => Table_Virtual_Addr;
         begin
            Initialise_Page_Table (New_Page_Table, Result);
            if Result /= Success then
               return Result;
            end if;
         end Init_Page_Table;

      --  Free the temporarily mapped structure.
      Free_Temporary_Page_Mapping (Table_Virtual_Addr, Result);
      if Result /= Success then
         return Result;
      end if;

      --  Set the output address to the address of the newly allocated frame.
      Page_Table_Addr := Allocated_Addr;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Create_Page_Table;

   ----------------------------------------------------------------------------
   --  Find_Free_Kernel_Page
   ----------------------------------------------------------------------------
   procedure Find_Free_Kernel_Page (
     Table_Index : out Paging_Index;
     Page_Index  : out Paging_Index;
     Status      : out Process_Result
   ) is
      --  The currently loaded kernel page_directory.
      Kernel_Page_Dir : constant Page_Directory
      with Import,
        Convention => Ada,
        Address    => To_Address (PAGE_DIR_RECURSIVE_ADDR);

      --  The address of each page table.
      --  This will be set to the address that each page table being checked
      --  is recursively mapped into memory.
      Table_Addr : System.Address;
   begin
      --  Initialise out params to NULL values.
      Table_Index := 0;
      Page_Index  := 0;

      --  Loop over every page in the directory, checking only the entries
      --  which are marked as present.
      --  The last two directory entries are ignored, since these are
      --  reserved for special functionality.
      for Dir_Entry_Idx in Paging_Index range 768 .. 1021 loop
         if Kernel_Page_Dir (Dir_Entry_Idx).Present then
            --  Get the address of this page table in memory.
            Status := Get_Page_Table_Mapped_Address (Dir_Entry_Idx,
              Table_Addr);
            if Status /= Success then
               return;
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
                  for Frame_Idx in Paging_Index'Range loop
                     if Kernel_Table (Frame_Idx).Present = False then
                        Table_Index := Dir_Entry_Idx;
                        Page_Index  := Frame_Idx;
                        Status      := Success;
                        return;
                     end if;
                  end loop;
               end Check_Page_Table;
         end if;
      end loop;

      --  Set the result status to indicate that there are no free frames.
      Status := No_Free_Frames;
   exception
      when Constraint_Error =>
         Status := Unhandled_Exception;
   end Find_Free_Kernel_Page;

   ----------------------------------------------------------------------------
   --  Free_Temporary_Page_Mapping
   ----------------------------------------------------------------------------
   procedure Free_Temporary_Page_Mapping (
     Virtual_Addr :     System.Address;
     Status       : out Process_Result
   ) is
      --  The table used for temporary mappings.
      Temp_Page_Table : Page_Table
      with Import,
        Convention => Ada,
        Address    => To_Address (TEMP_TABLE_RECURSIVE_ADDR);

      --  The index into the table of the entry to unmap.
      Table_Idx : Paging_Index;
   begin
      --  Ensure that the provided virtual address is within the temp table.
      Check_Virtual_Address :
         begin
            if (To_Integer (Virtual_Addr) < TEMP_TABLE_BASE_ADDR) or
              (To_Integer (Virtual_Addr) > TEMP_TABLE_BASE_ADDR + 16#400000#)
            then
               --  Return Invalid_Argument in the instance that the provided
               --  address is not mapped in the temporary table.
               Status := Invalid_Argument;
               return;
            end if;
         end Check_Virtual_Address;

      --  Get the index into the page table, based upon the provided virtual
      --  address.
      Get_Table_Mapping :
         begin
            --  Subtract the base of the temp table address from the provided
            --  virtual address, then divide it by the size of a page frame.
            Table_Idx := Paging_Index (To_Integer (Virtual_Addr) -
              TEMP_TABLE_BASE_ADDR) / 16#1000#;
         end Get_Table_Mapping;

      --  Set the table index to be non-present.
      Temp_Page_Table (Table_Idx).Present := False;

      --  Reload the TLB to free the mapping.
      Flush_Tlb;

      Status := Success;
   exception
      when Constraint_Error =>
         Status := Unhandled_Exception;
   end Free_Temporary_Page_Mapping;

   ----------------------------------------------------------------------------
   --  Get_Page_Table_Mapped_Address
   ----------------------------------------------------------------------------
   function Get_Page_Table_Mapped_Address (
     Table_Index :     Paging_Index;
     Mapped_Addr : out System.Address
   ) return Process_Result is
   begin
      Mapped_Addr := To_Address (PAGE_TABLES_BASE_ADDR
        + Integer_Address (16#1000# * Table_Index));

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Get_Page_Table_Mapped_Address;

   ----------------------------------------------------------------------------
   --  Get_Page_Table_Mapped_Address
   ----------------------------------------------------------------------------
   function Get_Page_Table_Mapped_Address (
     Virtual_Addr :     System.Address;
     Mapped_Addr  : out System.Address
   ) return Process_Result is
      --  The index into the page directory that this virtual address
      --  is mapped at.
      Directory_Idx : Paging_Index;
      --  The offset from the base mapping offset.
      Table_Offset  : Integer_Address := 0;
   begin
      --  Ensure that the provided address is properly page aligned.
      if not Check_Address_Page_Aligned (Virtual_Addr) then
         return Invalid_Non_Aligned_Address;
      end if;

      --  Get the directory index.
      Directory_Idx := Get_Page_Directory_Index (Virtual_Addr);

      Calculate_Mapped_Address :
         begin
            Table_Offset := Integer_Address (16#1000# * Directory_Idx);
            Mapped_Addr := To_Address (PAGE_TABLES_BASE_ADDR + Table_Offset);
         end Calculate_Mapped_Address;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Get_Page_Table_Mapped_Address;

   ----------------------------------------------------------------------------
   --  Initialise_Page_Directory
   ----------------------------------------------------------------------------
   procedure Initialise_Page_Directory (
     Page_Dir : in out x86.Memory.Paging.Page_Directory;
     Status   :    out Process_Result
   ) is
   begin
      --  Iterate over all 1024 directory entries.
      for Idx in Paging_Index'Range loop
         --  Initialise the individual entry.
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
      end loop;

      Status := Success;
   exception
      when Constraint_Error =>
         Status := Unhandled_Exception;
   end Initialise_Page_Directory;

   ----------------------------------------------------------------------------
   --  Initialise_Page_Table
   ----------------------------------------------------------------------------
   procedure Initialise_Page_Table (
     Table  : in out x86.Memory.Paging.Page_Table;
     Status :    out Process_Result
   ) is
   begin
      --  Iterate over all 1024 table entries.
      for Idx in Paging_Index'Range loop
         --  Initialise the individual entry.
         Table (Idx).Present      := False;
         Table (Idx).Read_Write   := True;
         Table (Idx).U_S          := False;
         Table (Idx).PWT          := False;
         Table (Idx).PCD          := False;
         Table (Idx).A            := False;
         Table (Idx).Page_Address :=
           Convert_To_Page_Aligned_Address (System.Null_Address);
      end loop;

      Status := Success;
   exception
      when Constraint_Error =>
         Status := Unhandled_Exception;
   end Initialise_Page_Table;

   ----------------------------------------------------------------------------
   --  Map_Virtual_Address
   ----------------------------------------------------------------------------
   procedure Map_Virtual_Address (
     Page_Dir      :     x86.Memory.Paging.Page_Directory;
     Virtual_Addr  :     System.Address;
     Physical_Addr :     System.Address;
     Status        : out Process_Result;
     Read_Write    :     Boolean := True;
     User_Mode     :     Boolean := False
   ) is
      --  The index into the page directory of the virtual address.
      Directory_Idx : Paging_Index;
      --  The index into the relevant page table of the virtual address.
      Table_Idx     : Paging_Index;
      --  The physical address of the relevant page table.
      Table_Addr    : System.Address;
   begin
      --  Ensure that the provided addresses are 4K aligned.
      if not Check_Address_Page_Aligned (Virtual_Addr) or
        Check_Address_Page_Aligned (Physical_Addr)
      then
         Status := Invalid_Non_Aligned_Address;
         return;
      end if;

      --  Get the index into the page directory needed to map this page.
      Directory_Idx := Get_Page_Directory_Index (Virtual_Addr);
      --  Get the index into the relevant page table.
      Table_Idx := Get_Page_Table_Index (Virtual_Addr);

      --  Get the page table physical address.
      --  If the table is not present in the directory, a new table will be
      --  allocated and the physical address of the new table returned.
      --  Otherwise, the recursively mapped table address will be used.
      if Page_Dir (Directory_Idx).Present = False then
         Status := Get_Page_Table_Mapped_Address (Directory_Idx, Table_Addr);
      else
         Status := Create_Page_Table (Table_Addr);
      end if;

      if Status /= Success then
         return;
      end if;

      --  Map the virtual address.
      Map_Frame :
         declare
            --  The table in which we will map the frame.
            Entry_Table : Page_Table
            with Import,
              Convention => Ada,
              Address    => Table_Addr;
         begin
            --  Initialise the entry.
            --  Note: This function ignores whether this entry was already
            --  mapped.
            Entry_Table (Table_Idx).Present      := True;
            Entry_Table (Table_Idx).Page_Address :=
              Convert_To_Page_Aligned_Address (Physical_Addr);
            Entry_Table (Table_Idx).Read_Write   := Read_Write;
            Entry_Table (Table_Idx).U_S          := User_Mode;

            --  Reload the TLB to load the new mapping.
            Flush_Tlb;
         end Map_Frame;

      Status := Success;
   exception
      when Constraint_Error =>
         Status := Unhandled_Exception;
   end Map_Virtual_Address;

   ----------------------------------------------------------------------------
   --  Temporarily_Map_Page
   ----------------------------------------------------------------------------
   procedure Temporarily_Map_Page (
     Frame_Addr   :     System.Address;
     Virtual_Addr : out System.Address;
     Status       : out Process_Result
   ) is
      --  The temporary mapping page table.
      Temp_Page_Table : Page_Table
      with Import,
        Convention => Ada,
        Address    => To_Address (TEMP_TABLE_RECURSIVE_ADDR);
   begin
      --  Set the output address to null as a default fallback.
      Virtual_Addr := System.Null_Address;

      --  Check each frame entry in the page table to find a free entry.
      for Frame_Idx in Paging_Index'Range loop
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

            Status := Success;
            return;
         end if;
      end loop;

      --  If we iterate through the entire table and cannot find a free
      --  frame, set this result.
      Status := No_Free_Frames;
   exception
      when Constraint_Error =>
         Status := Unhandled_Exception;
   end Temporarily_Map_Page;

end Cxos.Memory.Paging;
