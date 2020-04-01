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

with System.Storage_Elements;
with Cxos.Memory;
with Cxos.Memory.Paging;
with Cxos.Serial;

package body Cxos.Process is
   ----------------------------------------------------------------------------
   --  Create_Initial_Kernel_Task
   ----------------------------------------------------------------------------
   function Create_Initial_Kernel_Task (
     Process_Block : out Process_Control_Block
   ) return Process_Result is
   begin
      --  Set the page directory pointer to the currently loaded page
      --  directory pointer.
      Process_Block.Id  := Process_Count;
      Process_Block.CR3 := Cxos.Memory.Paging.Current_Page_Dir_Ptr;
      Process_Block.ESP := Cxos.Memory.Get_Stack_Top;

      --  Increment the process count.
      Increment_Process_Count :
         begin
            Process_Count := Process_Count + 1;
         exception
            when Constraint_Error =>
               Cxos.Serial.Put_String ("Process count exhausted" & ASCII.LF);
               return Unhandled_Exception;
         end Increment_Process_Count;

      return Success;
   end Create_Initial_Kernel_Task;

   ----------------------------------------------------------------------------
   --  Create_Task
   ----------------------------------------------------------------------------
   function Create_Process (
     Process_Block : out Process_Control_Block;
     Func_Start    :     System.Address
   ) return Process_Result is
      use System.Storage_Elements;

      --  The newly allocated page directory to map the virtual address
      --  space for the newly created process.
      Page_Dir_Addr     : System.Address;
   begin
      --  Allocate the page directory for the newly created process.
      Allocate_Page_Directory :
         declare
            use Cxos.Memory;

            --  The result of allocating the new page directory.
            Allocate_Result : Cxos.Memory.Process_Result;
         begin
            Allocate_Result := Cxos.Memory.Paging.
              Create_New_Address_Space (Page_Dir_Addr, Func_Start);
            if Allocate_Result /= Success then
               Cxos.Serial.Put_String ("Error allocating new address block" &
                 ASCII.LF);
               return Unhandled_Exception;
            end if;
         end Allocate_Page_Directory;

      --  Allocate the process control block.
      Allocate_Structure :
         begin
            Process_Block.Id  := Process_Count;
            Process_Block.CR3 := Page_Dir_Addr;
            Process_Block.ESP := To_Address (16#FF003FF4#);
         end Allocate_Structure;

      --  Increment the process count.
      Increment_Process_Count :
         begin
            Process_Count := Process_Count + 1;
         exception
            when Constraint_Error =>
               Cxos.Serial.Put_String ("Process count exhausted" & ASCII.LF);
               return Unhandled_Exception;
         end Increment_Process_Count;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Create_Process;

   ----------------------------------------------------------------------------
   --  Find_Next_Process
   ----------------------------------------------------------------------------
   function Find_Next_Process (
     Next_Process : out Process_Control_Block
   ) return Process_Result is
      Next_Process_Id : Natural;
   begin
      if Process_Count = 0 then
         return No_Running_Processes;
      end if;

         Find_Next_Process_Id :
            begin
               Next_Process_Id := (Current_Process_Id + 1) mod Process_Count;
            exception
               when Constraint_Error =>
                  Next_Process_Id := 0;
            end Find_Next_Process_Id;

         Cxos.Serial.Put_String ("C: " & Current_Process_Id'Image &
           " N: " & Next_Process_Id'Image & ASCII.LF);

         Next_Process := System_Processes (Next_Process_Id);
      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Find_Next_Process;

   ----------------------------------------------------------------------------
   --  Idle
   ----------------------------------------------------------------------------
   procedure Idle is
      Idle_Count : Natural := 0;
      Start_Time : Time;
   begin

      --  Loop forever.
      loop
         Start_Time := Clock;
            Cxos.Serial.Put_String ("Idling: " & Idle_Count'Image & ASCII.LF);
            Idle_Count := Idle_Count + 1;

            Wait_Loop :
               loop
                  if (Clock - Start_Time) > 1000 then
                     exit Wait_Loop;
                  end if;
               end loop Wait_Loop;

            Yield;
      end loop;
   exception
      when Constraint_Error =>
         null;
   end Idle;

   ----------------------------------------------------------------------------
   --  Initialise
   ----------------------------------------------------------------------------
   procedure Initialise is
      --  The result status code of internal processes.
      Result : Process_Result;
   begin
      Cxos.Serial.Put_String ("Initialising system proceses" & ASCII.LF);

      Current_Process_Id := 0;

      --  Create the system idle process from the pseudo-process currently
      --  running from boot.
      Create_Idle_Process :
         begin
            --  Result := Create_Initial_Kernel_Task (Idle_Task);
            Result := Create_Initial_Kernel_Task (System_Processes (0));
            if Result /= Success then
               Cxos.Serial.Put_String ("Error creating idle task" & ASCII.LF);
            end if;

            --  Print_Process_Block_Info (System_Processes (0));
         end Create_Idle_Process;

      Create_Test_Process :
         begin
            Result := Create_Process (System_Processes (1), Idle'Address);
            if Result /= Success then
               Cxos.Serial.Put_String ("Error" & ASCII.LF);
            end if;

            --  Print_Process_Block_Info (System_Processes (1));
         end Create_Test_Process;

      Cxos.Serial.Put_String ("Finished initialising system proceses" &
        ASCII.LF);

      Yield;
   exception
      when Constraint_Error =>
         null;
   end Initialise;

   ----------------------------------------------------------------------------
   --  Print_Process_Block_Info
   ----------------------------------------------------------------------------
   procedure Print_Process_Block_Info (
     Proc : Process_Control_Block
   ) is
      use System.Storage_Elements;

      CR3 : constant Integer_Address := To_Integer (Proc.CR3);
      ESP : constant Integer_Address := To_Integer (Proc.ESP);
   begin
      Cxos.Serial.Put_String ("Process Id: " & Proc.Id'Image & ASCII.LF);
      Cxos.Serial.Put_String ("  CR3: " & CR3'Image & ASCII.LF);
      Cxos.Serial.Put_String ("  ESP: " & ESP'Image & ASCII.LF);
      Cxos.Serial.Put_String ("------------------------" & ASCII.LF);
   end Print_Process_Block_Info;

   ----------------------------------------------------------------------------
   --  Run_Scheduler
   ----------------------------------------------------------------------------
   procedure Run_Scheduler is
      Old_Process_Id : Natural;
      Next_Process   : Process_Control_Block;
      Result         : Process_Result;
   begin
      --  Don't run if there are no active processes.
      if Process_Count = 0 then
         return;
      end if;

      Old_Process_Id := Current_Process_Id;

      Result := Find_Next_Process (Next_Process);
      if Result /= Success then
         Cxos.Serial.Put_String ("Error finding next process" & ASCII.LF);
         return;
      end if;

      Cxos.Serial.Put_String ("Switching to process: " &
        Next_Process.Id'Image & ASCII.LF);
      Print_Process_Block_Info (Next_Process);

      Switch_To_Process (System_Processes (Old_Process_Id), Next_Process);
   exception
      when Constraint_Error =>
         Cxos.Serial.Put_String ("Error running scheduler" & ASCII.LF);
         null;
   end Run_Scheduler;

   ----------------------------------------------------------------------------
   --  Switch_To_Process
   ----------------------------------------------------------------------------
   procedure Switch_To_Process (
     Old_Process    : Process_Control_Block;
     Target_Process : Process_Control_Block
   ) is
   begin
      Current_Process_Id := Target_Process.Id;

      --  Save the state of the currently running process.
      Save_Process_State (Old_Process);
      --  Load the new process.
      Load_Process (Target_Process);
      --  Reset clock.
      Curr_Process_Slice_Start_Time := Cxos.Time_Keeping.Clock;
   exception
      when Constraint_Error =>
         null;
   end Switch_To_Process;

   procedure Yield is
   begin
      Run_Scheduler;
   end Yield;
end Cxos.Process;
