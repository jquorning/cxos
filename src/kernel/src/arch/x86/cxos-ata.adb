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
with System;
with x86.Port_IO;

package body Cxos.ATA is
   use x86.ATA;

   ----------------------------------------------------------------------------
   --  Get_Device_Type
   ----------------------------------------------------------------------------
   function Get_Device_Type (
     Device_Type : out x86.ATA.ATA_Device_Type;
     Bus         :     x86.ATA.ATA_Bus;
     Position    :     x86.ATA.ATA_Device_Position
   ) return Process_Result is
      --  The result of internal processes.
      Result             : Process_Result;
      --  The Cylinder high register port address.
      Cylinder_High_Port : System.Address;
      --  The Cylinder Low register port address.
      Cylinder_Low_Port  : System.Address;

      --  The cylinder low value.
      Drive_Cylinder_Low  : Unsigned_8;
      --  The cylinder high value.
      Drive_Cylinder_High : Unsigned_8;
   begin
      --  Select the master/slave device.
      Result := Select_Device_Position (Bus, Position);
      if Result /= Success then
         return Result;
      end if;

      --  Get the device port addresses used.
      Cylinder_Low_Port  := Get_Register_Address (Bus, Cylinder_Low);
      Cylinder_High_Port := Get_Register_Address (Bus, Cylinder_High);

      --  Wait until the device is ready to receive commands.
      Result := Wait_For_Device_Ready (Bus, 10000);
      if Result /= Success then
         return Result;
      end if;

      --  Read device identification info.
      Drive_Cylinder_High := x86.Port_IO.Inb (Cylinder_High_Port);
      Drive_Cylinder_Low  := x86.Port_IO.Inb (Cylinder_Low_Port);

      if Drive_Cylinder_Low = 16#14# and Drive_Cylinder_High = 16#EB# then
         Device_Type := PATAPI;
      elsif Drive_Cylinder_Low = 16#69# and Drive_Cylinder_High = 16#96# then
         Device_Type := SATAPI;
      elsif Drive_Cylinder_Low = 16#3C# and Drive_Cylinder_High = 16#C3# then
         Device_Type := SATA;
      elsif Drive_Cylinder_Low = 0 and Drive_Cylinder_High = 0 then
         Device_Type := PATA;
      else
         Device_Type := Unknown_ATA_Device;
      end if;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Get_Device_Type;

   ----------------------------------------------------------------------------
   --  Identify
   ----------------------------------------------------------------------------
   function Identify (
     Id_Record : out x86.ATA.Device_Identification_Record;
     Bus       :     x86.ATA.ATA_Bus;
     Position  :     x86.ATA.ATA_Device_Position
   ) return Process_Result is
      --  The ATA device ports used in the device identification process.
      Sector_Count_Port  : System.Address;
      Sector_Number_Port : System.Address;
      Cylinder_High_Port : System.Address;
      Cylinder_Low_Port  : System.Address;
      Alt_Status_Port    : System.Address;
      Data_Port          : System.Address;

      --  The raw status value read from the device.
      Status_Read_Value   : Unsigned_8;
      --  The device cylinder high value, used to find device type/status.
      Cylinder_High_Value : Unsigned_16;
      --  The device cylinder low value.
      Cylinder_Low_Value  : Unsigned_16;

      --  The result of internal processes.
      Result : Process_Result;
      --  Buffer to read the device identification info into.
      Identification_Buffer : Device_Identification_Buffer;
   begin
      --  Get the device port addresses used.
      Get_Port_Addresses :
         begin
            Sector_Count_Port  := Get_Register_Address (Bus, Sector_Count);
            Sector_Number_Port := Get_Register_Address (Bus, Sector_Number);
            Cylinder_Low_Port  := Get_Register_Address (Bus, Cylinder_Low);
            Cylinder_High_Port := Get_Register_Address (Bus, Cylinder_High);
            Alt_Status_Port    := Get_Register_Address (Bus, Alt_Status);
            Data_Port          := Get_Register_Address (Bus, Data_Reg);
         end Get_Port_Addresses;

      Send_Identify_Command :
         begin
            --  Reset these to 0 as per the ATA spec.
            x86.Port_IO.Outw (Sector_Count_Port, 0);
            x86.Port_IO.Outw (Sector_Number_Port, 0);
            x86.Port_IO.Outw (Cylinder_High_Port, 0);
            x86.Port_IO.Outw (Cylinder_Low_Port, 0);

            --  Select the master/slave device.
            Result := Select_Device_Position (Bus, Position);
            if Result /= Success then
               return Result;
            end if;

            --  Send the identify command.
            Result := Send_Command (Bus, Identify_Device);
            if Result /= Success then
               return Result;
            end if;

            --  Read the device status.
            Status_Read_Value := x86.Port_IO.Inb (Alt_Status_Port);
            if Status_Read_Value = 0 then
               return Device_Not_Present;
            end if;

            Cylinder_High_Value := x86.Port_IO.Inw (Cylinder_High_Port);
            Cylinder_Low_Value  := x86.Port_IO.Inw (Cylinder_Low_Port);

            if (Cylinder_High_Value /= 0) or (Cylinder_Low_Value /= 0) then
               return Device_Non_ATA;
            end if;

            --  Read the device status until the device is ready.
            Result := Wait_For_Device_Ready (Bus);
            if Result /= Success then
               return Result;
            end if;
         end Send_Identify_Command;

      --  Read in the identification buffer.
      Read_Identification :
         begin
            for I in Integer range 0 .. 255 loop
               Identification_Buffer (I) := x86.Port_IO.Inw (Data_Port);
            end loop;

            --  Convert the raw buffer to the identification record.
            Id_Record := Device_Identification_Buffer_To_Record (
              Identification_Buffer);
         end Read_Identification;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Identify;

   procedure Initialise is
      Device_Type : x86.ATA.ATA_Device_Type;
      Result      : Process_Result;
      Rec : Device_Identification_Record;
   begin
      Result := Reset_Bus (Primary);
      if Result /= Success then
         Cxos.Serial.Put_String ("Error resetting device" & ASCII.LF);
      end if;

      Result := Get_Device_Type (Device_Type, Primary, Master);
      if Result /= Success then
         Cxos.Serial.Put_String ("Error reading device type" & ASCII.LF);
      end if;

      case Device_Type is
         when PATAPI =>
            Cxos.Serial.Put_String ("PATAPI" & ASCII.LF);
         when SATAPI =>
            Cxos.Serial.Put_String ("PATAPI" & ASCII.LF);
         when PATA   =>
            Cxos.Serial.Put_String ("PATA" & ASCII.LF);
         when SATA   =>
            Cxos.Serial.Put_String ("SATA" & ASCII.LF);
         when Unknown_ATA_Device =>
            Cxos.Serial.Put_String ("Unknown" & ASCII.LF);
      end case;

      Result := Identify (Rec, Primary, Master);
      if Result /= Success then
         Cxos.Serial.Put_String ("Error identifying device" & ASCII.LF);
      end if;

      if Rec.Device_Config.Removable_Media = True then
         Cxos.Serial.Put_String ("Removable Media" & ASCII.LF);
      end if;

      Result := Get_Device_Type (Device_Type, Primary, Slave);
      if Result /= Success then
         Cxos.Serial.Put_String ("Error reading device type" & ASCII.LF);
      end if;

      case Device_Type is
         when PATAPI =>
            Cxos.Serial.Put_String ("PATAPI" & ASCII.LF);
         when SATAPI =>
            Cxos.Serial.Put_String ("PATAPI" & ASCII.LF);
         when PATA   =>
            Cxos.Serial.Put_String ("PATA" & ASCII.LF);
         when SATA   =>
            Cxos.Serial.Put_String ("SATA" & ASCII.LF);
         when Unknown_ATA_Device =>
            Cxos.Serial.Put_String ("Unknown" & ASCII.LF);
      end case;
   exception
      when Constraint_Error =>
         return;
   end Initialise;

   function Read_Word (
     Data : out Unsigned_16;
     Bus  :     x86.ATA.ATA_Bus
   ) return Process_Result is
      Result : Process_Result;
   begin
      Result := Send_Command (Bus, Read_Long_Retry);
      if Result /= Success then
         return Result;
      end if;

      Data := 1;

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Read_Word;

   ----------------------------------------------------------------------------
   --  Reset_Bus
   ----------------------------------------------------------------------------
   function Reset_Bus (
     Bus : x86.ATA.ATA_Bus
   ) return Process_Result is
      --  The address of the device control register.
      Control_Register_Address : System.Address;
   begin
      Control_Register_Address := x86.ATA.Get_Register_Address (Bus,
        Device_Control);

      x86.Port_IO.Outb (Control_Register_Address, 4);
      x86.Port_IO.Outb (Control_Register_Address, 0);

      return Success;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Reset_Bus;

   ----------------------------------------------------------------------------
   --  Select_Device_Position
   ----------------------------------------------------------------------------
   function Select_Device_Position (
     Bus      : x86.ATA.ATA_Bus;
     Position : x86.ATA.ATA_Device_Position
   ) return Process_Result is
      --  The address of the Device Select port.
      Device_Select_Port : System.Address;
   begin
      --  Get the Device Select Port for this device.
      Get_Device_Select_Port :
         begin
            Device_Select_Port := x86.ATA.Get_Register_Address (Bus,
              Drive_Head);
         exception
            when Constraint_Error =>
               return Unhandled_Exception;
         end Get_Device_Select_Port;

      --  Sends the signal to select the specified device position.
      Send_Device_Select_Signal :
         begin
            case Position is
               when Master =>
                  x86.Port_IO.Outb (Device_Select_Port, 16#A0#);
               when Slave  =>
                  x86.Port_IO.Outb (Device_Select_Port, 16#B0#);
            end case;
         exception
            when Constraint_Error =>
               return Unhandled_Exception;
         end Send_Device_Select_Signal;

      return Success;
   end Select_Device_Position;

   ----------------------------------------------------------------------------
   --  Send_Command
   ----------------------------------------------------------------------------
   function Send_Command (
     Bus          : x86.ATA.ATA_Bus;
     Command_Type : x86.ATA.ATA_Command
   ) return Process_Result is
      --  The bus command register address.
      Command_Register : System.Address;
      --  The byte value to send.
      Command_Byte     : Unsigned_8;
   begin
      --  Set the command byte to send.
      Set_Command_Byte :
         begin
            case Command_Type is
               when Nop =>
                  Command_Byte := 0;
               when Device_Reset =>
                  Command_Byte := 16#08#;
               when Recalibrate =>
                  Command_Byte := 16#10#;
               when Read_Sectors_Retry =>
                  Command_Byte := 16#20#;
               when Read_Sectors_No_Retry =>
                  Command_Byte := 16#21#;
               when Read_Long_Retry =>
                  Command_Byte := 16#22#;
               when Read_Long_No_Retry =>
                  Command_Byte := 16#23#;
               when Read_Sectors_Ext =>
                  Command_Byte := 16#24#;
               when Read_DMA_Ext =>
                  Command_Byte := 16#25#;
               when Identify_Device =>
                  Command_Byte := 16#EC#;
               when others =>
                  return Invalid_Command;
            end case;
         exception
            when Constraint_Error =>
               return Invalid_Command;
         end Set_Command_Byte;

         --  Get the command register address.
      Get_Command_Register :
         begin
            Command_Register := x86.ATA.Get_Register_Address (Bus,
              Command_Reg);
         exception
            when Constraint_Error =>
               return Unhandled_Exception;
         end Get_Command_Register;

         --  Send Command.
         x86.Port_IO.Outb (Command_Register, Command_Byte);

      return Success;
   end Send_Command;

   ----------------------------------------------------------------------------
   --  Wait_For_Device_Ready
   ----------------------------------------------------------------------------
   function Wait_For_Device_Ready (
     Bus     : x86.ATA.ATA_Bus;
     Timeout : Cxos.Time_Keeping.Time := 2000
   ) return Process_Result is
      use Cxos.Time_Keeping;

      --  The address of the device alt status port.
      Alt_Status_Port : System.Address;
      --  The status value read from the device.
      Drive_Status    : x86.ATA.Device_Status_Record;
      --  The system time at the start of the function.
      Start_Time      : Cxos.Time_Keeping.Time;
      --  The current system time.
      Current_Time    : Cxos.Time_Keeping.Time;
   begin
      --  Get the port address of the alt status register.
      Alt_Status_Port := Get_Register_Address (Bus, Alt_Status);
      --  Get the start time.
      Start_Time := Cxos.Time_Keeping.Clock;

      --  Read the device status register in a loop until either the
      --  timeout is exceeded and the function exits, or a non-busy
      --  status is read.
      Wait_While_Busy :
         loop
            --  Read device status.
            Drive_Status := x86.ATA.Unsigned_8_To_Device_Status_Record (
              x86.Port_IO.Inb (Alt_Status_Port));
            if Drive_Status.BSY = False then
               return Success;
            end if;

            --  If an error state is reported, exit here.
            if Drive_Status.ERR = True then
               return Device_Error_State;
            end if;

            --  Check to see whether we have exceeded the timeout threshold.
            --  If so, exit the loop.
            Check_Timeout :
               begin
                  Current_Time := Cxos.Time_Keeping.Clock;
                  if (Current_Time - Start_Time) > Timeout then
                     exit Wait_While_Busy;
                  end if;
               end Check_Timeout;
         end loop Wait_While_Busy;

      --  If no value has been returned within the attempt threshold,
      --  return this status.
      return Device_Busy;
   exception
      when Constraint_Error =>
         return Unhandled_Exception;
   end Wait_For_Device_Ready;
end Cxos.ATA;