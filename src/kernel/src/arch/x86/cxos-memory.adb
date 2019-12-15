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

with Cxos.Serial;
with Cxos.Memory.Map;
with Interfaces;
with System.Storage_Elements; use System.Storage_Elements;

package body Cxos.Memory is
   use Interfaces;

   ----------------------------------------------------------------------------
   --  Clear_Boot_Page_Structures
   ----------------------------------------------------------------------------
   function Clear_Boot_Page_Structures return Process_Result is
      use Cxos.Memory.Map;

      --  The result of the frame status set process.
      Result : Process_Result;

      --  The boot page directory.
      --  Import as an Unsigned int, since we don't care what kind of
      --  structure is at this memory address. We only need to clear it.
      Boot_Page_Directory : constant Unsigned_32
      with Import,
        Convention    => Assembler,
        External_Name => "boot_page_directory";

      --  The boot page table.
      Boot_Page_Table     : constant Unsigned_32
      with Import,
        Convention    => Assembler,
        External_Name => "boot_page_table";
   begin
      Result := Cxos.Memory.Map.Mark_Memory_Range (
        Boot_Page_Directory'Address, 16#1000#, Unallocated);
      if Result /= Success then
         Cxos.Serial.Put_String (
           "Error freeing boot page directory" & ASCII.LF);
         return Unhandled_Exception;
      end if;

      Result := Cxos.Memory.Map.Mark_Memory_Range (
        Boot_Page_Table'Address, 16#1000#, Unallocated);
      if Result /= Success then
         Cxos.Serial.Put_String (
           "Error freeing boot page table" & ASCII.LF);
         return Unhandled_Exception;
      end if;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Clear_Boot_Page_Structures;

   ----------------------------------------------------------------------------
   --  Create_Process_Address_Space
   --
   --  Purpose:
   --    Creates a new virtual address space for a new process.
   ----------------------------------------------------------------------------
   function Create_Process_Address_Space (
     Page_Directory_Addr : out System.Address
   ) return Process_Result is
   begin
      Page_Directory_Addr := To_Address (0);

      return Success;
   end Create_Process_Address_Space;

   ----------------------------------------------------------------------------
   --  Initialise
   ----------------------------------------------------------------------------
   function Initialise return Process_Result is
   begin
      --  Mark used memory.
      Map_System_Memory :
         declare
            --  The result of the internal processes.
            Result : Process_Result;
         begin
            Cxos.Serial.Put_String ("Marking kernel memory used" & ASCII.LF);
            Result := Mark_Kernel_Memory;
            if Result /= Success then
               Cxos.Serial.Put_String (
                 "Error marking kernel memory" & ASCII.LF);
               return Result;
            end if;
            Cxos.Serial.Put_String ("Finished marking kernel memory" &
              ASCII.LF);
         end Map_System_Memory;

      --  Mark the boot paging structures as free, since they are no
      --  longer needed.
      Mark_Boot_Memory :
         declare
            --  The result of the internal processes.
            Result : Process_Result;
         begin
            Cxos.Serial.Put_String ("Freeing boot paging structure memory" &
              ASCII.LF);
            Result := Clear_Boot_Page_Structures;
            if Result /= Success then
               Cxos.Serial.Put_String (
                 "Error freeing boot paging memory" & ASCII.LF);
               return Result;
            end if;
            Cxos.Serial.Put_String ("Finished freeing boot paging " &
              "structure memory" & ASCII.LF);
         end Mark_Boot_Memory;
      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Initialise;

   ----------------------------------------------------------------------------
   --  Mark_Kernel_Memory
   --
   --  Implementation Notes:
   --    - Marks the kernel's physical memory as being used.
   ----------------------------------------------------------------------------
   function Mark_Kernel_Memory return Process_Result is
      use Cxos.Memory.Map;

      --  The length of the kernel code segment in bytes.
      Kernel_Length    : Unsigned_32 := 0;

      --  The result of the frame status set process.
      Result : Process_Result := Success;

      --  The start of the kernel code segment.
      Kernel_Start     : constant Unsigned_32
      with Import,
        Convention    => Assembler,
        External_Name => "kernel_start";
      --  The end of the kernel code segment.
      Kernel_End       : constant Unsigned_32
      with Import,
        Convention    => Assembler,
        External_Name => "kernel_end";
      --  The address of the kernel in virtual memory.
      Kernel_Vma_Start : constant Unsigned_32
      with Import,
        Convention    => Assembler,
        External_name => "KERNEL_VMA_START";

      --  The physical start of Kernel memory.
      Kernel_Physical_Start : System.Address := To_Address (0);
   begin
      Kernel_Length   := Unsigned_32 (
        To_Integer (Kernel_End'Address) -
        To_Integer (Kernel_Start'Address));

      --  The kernel's physical start is the virtual memory logical start
      --  subtracted from the kernel memory start.
      Kernel_Physical_Start := To_Address (
        To_Integer (Kernel_Start'Address) -
        To_Integer (Kernel_Vma_Start'Address));

      Result := Cxos.Memory.Map.Mark_Memory_Range (
        Kernel_Physical_Start, Kernel_Length, Allocated);
      if Result /= Success then
         Cxos.Serial.Put_String (
           "Error marking kernel code segment" & ASCII.LF);

         return Unhandled_Exception;
      end if;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Mark_Kernel_Memory;

end Cxos.Memory;
