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

with Ada.Unchecked_Conversion;
with Interfaces; use Interfaces;
with System;

-------------------------------------------------------------------------------
--  CXOS.FILESYSTEMS.FAT
--
--  Purpose:
--    This package contains definitons and functionality for working with
--    FAT filesystems.
-------------------------------------------------------------------------------
package Cxos.Filesystems.FAT is
   pragma Preelaborate;

   ----------------------------------------------------------------------------
   --  Program status type.
   --  Used to track the results of functions.
   ----------------------------------------------------------------------------
   type Program_Status is (
     Failure,
     Success
   );

   ----------------------------------------------------------------------------
   --  The type of FAT filesystem.
   ----------------------------------------------------------------------------
   type FAT_Type_T is (
     FAT12,
     FAT16,
     FAT32,
     ExFAT
   );

   ----------------------------------------------------------------------------
   --  Boot jump bytest type.
   --  Contains the filesystem's boot jump bytes.
   ----------------------------------------------------------------------------
   type Boot_Jump_Bytes_T is
     array (1 .. 3) of Unsigned_8;

   ----------------------------------------------------------------------------
   --  The BIOS parameter block.
   --  Represents a DOS 3.31 BPB type.
   ----------------------------------------------------------------------------
   type BIOS_Parameter_Block is
      record
         Bytes_Per_Sector      : Unsigned_16;
         Sectors_Per_Cluster   : Unsigned_8;
         Reserved_Sector_Count : Unsigned_16;
         Table_Count           : Unsigned_8;
         Root_Entry_Count      : Unsigned_16;
         Total_Sector_Count    : Unsigned_16;
         Media_Type            : Unsigned_8;
         Table_Size            : Unsigned_16;
         Sectors_Per_Track     : Unsigned_16;
         Head_Side_Count       : Unsigned_16;
         Hidden_Sector_Count   : Unsigned_32;
         Large_Sector_Count    : Unsigned_32;
      end record
   with Size => 200;
   for BIOS_Parameter_Block use
      record
         Bytes_Per_Sector      at 0 range 0   .. 15;
         Sectors_Per_Cluster   at 0 range 16  .. 23;
         Reserved_Sector_Count at 0 range 24  .. 39;
         Table_Count           at 0 range 40  .. 47;
         Root_Entry_Count      at 0 range 48  .. 63;
         Total_Sector_Count    at 0 range 64  .. 79;
         Media_Type            at 0 range 80  .. 87;
         Table_Size            at 0 range 88  .. 103;
         Sectors_Per_Track     at 0 range 104 .. 119;
         Head_Side_Count       at 0 range 120 .. 135;
         Hidden_Sector_Count   at 0 range 136 .. 167;
         Large_Sector_Count    at 0 range 168 .. 199;
      end record;

   ----------------------------------------------------------------------------
   --  Extended BIOS parameter block.
   --  Used in FAT12/FAT16 filesystems.
   ----------------------------------------------------------------------------
   type Extended_BIOS_Parameter_Block is
      record
         BPB                     : BIOS_Parameter_Block;
         Physical_Drive_Number   : Unsigned_8;
         Reserved                : Unsigned_8;
         Extended_Boot_Signature : Unsigned_8;
         Volume_Id               : Unsigned_32;
         Partition_Volume_Label  : String (1 .. 11);
         File_System_Type        : String (1 .. 8);
      end record
   with Size => 408;
   for Extended_BIOS_Parameter_Block use
      record
         BPB                     at 0 range 0   .. 199;
         Physical_Drive_Number   at 0 range 200 .. 207;
         Reserved                at 0 range 208 .. 215;
         Extended_Boot_Signature at 0 range 216 .. 223;
         Volume_Id               at 0 range 224 .. 255;
         Partition_Volume_Label  at 0 range 256 .. 343;
         File_System_Type        at 0 range 344 .. 407;
      end record;

   ----------------------------------------------------------------------------
   --  Reserved area in the FAT 32 BPB.
   ----------------------------------------------------------------------------
   type FAT32_Reserved_Buffer is array (0 .. 11) of Character;

   ----------------------------------------------------------------------------
   --  FAT32 Extended BIOS Parameter Block type.
   ----------------------------------------------------------------------------
   type FAT32_Extended_BIOS_Parameter_Block is
      record
         BPB              : BIOS_Parameter_Block;
         Table_Size       : Unsigned_32;
         Drive_Desc       : Unsigned_16;
         Version          : Unsigned_16;
         Root_Cluster     : Unsigned_32;
         Info_Sector      : Unsigned_16;
         Backup_BS_Sector : Unsigned_16;
         Reserved         : FAT32_Reserved_Buffer;
         Drive_Number     : Unsigned_8;
         Reserved_1       : Unsigned_8;
         Boot_Signature   : Unsigned_8;
         Volume_ID        : Unsigned_8;
         Volume_Label     : String (1 .. 11);
         Type_Label       : String (1 .. 8);
      end record
   with Size => 610;
   for FAT32_Extended_BIOS_Parameter_Block use
      record
         BPB              at 0 range 0   .. 199;
         Table_Size       at 0 range 200 .. 231;
         Drive_Desc       at 0 range 232 .. 247;
         Version          at 0 range 248 .. 265;
         Root_Cluster     at 0 range 266 .. 297;
         Info_Sector      at 0 range 298 .. 313;
         Backup_BS_Sector at 0 range 314 .. 329;
         Reserved         at 0 range 330 .. 425;
         Drive_Number     at 0 range 426 .. 433;
         Reserved_1       at 0 range 434 .. 441;
         Boot_Signature   at 0 range 442 .. 449;
         Volume_ID        at 0 range 450 .. 457;
         Volume_Label     at 0 range 458 .. 545;
         Type_Label       at 0 range 546 .. 609;
      end record;

   ----------------------------------------------------------------------------
   --  This buffer type represents the space reserved in the FAT boot sector
   --  for the BIOS Parameter Block.
   --  This reserved buffer type is used since we will not know ahead of time
   --  what FAT type we are dealing with, and will need to be able to convert
   --  between the different BPB types.
   ----------------------------------------------------------------------------
   type Reserved_BIOS_Parameter_Block_Buffer is
     array (Natural range 0 .. 89) of Unsigned_8;

   ----------------------------------------------------------------------------
   --  Type representing the boot sector in a FAT formatted device.
   --  This contains the BIOS Parameter Block typed as a blank buffer which
   --  can be cast to the relevant type depending on the FAT version.
   ----------------------------------------------------------------------------
   type Boot_Sector is
      record
         Boot_Jump  : Boot_Jump_Bytes_T;
         OEM_Name   : String (1 .. 8);
         BPB_Buffer : Reserved_BIOS_Parameter_Block_Buffer;
      end record;
   for Boot_Sector use
      record
         Boot_Jump  at 0 range 0  .. 23;
         OEM_Name   at 0 range 24 .. 87;
         BPB_Buffer at 0 range 88 .. 807;
      end record;

   ----------------------------------------------------------------------------
   --  An entry in a FAT12 formatted table.
   ----------------------------------------------------------------------------
   type FAT12_Table_Entry is mod 2 ** 12
   with Size => 12;

   ----------------------------------------------------------------------------
   --  The file allocation table in a FAT12 formatted device.
   ----------------------------------------------------------------------------
   type FAT12_Table is
     array (Natural range <>) of FAT12_Table_Entry
     with Pack;

   ----------------------------------------------------------------------------
   --  An entry into a FAT16 formatted table.
   ----------------------------------------------------------------------------
   type FAT16_Table_Entry is new Unsigned_16;

   ----------------------------------------------------------------------------
   --  The file allocation table in a FAT16 formatted device.
   ----------------------------------------------------------------------------
   type FAT16_Table is
     array (Natural range <>) of FAT16_Table_Entry
     with Pack;

   ----------------------------------------------------------------------------
   --  File name entry attributes type.
   ----------------------------------------------------------------------------
   type Directory_Entry_Attributes is (
     Read_Only,
     Hidden,
     System_Entry,
     Volume_Id,
     Long_File_Name_Entry,
     Directory,
     Archive
   )
   with Size => 8;
   for Directory_Entry_Attributes use (
     Read_Only            => 1,
     Hidden               => 2,
     System_Entry         => 4,
     Volume_Id            => 8,
     Long_File_Name_Entry => 15,
     Directory            => 16,
     Archive              => 32
   );

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------
   type Directory_Entry is
      record
         File_Name          : String (1 .. 11);
         Attributes         : Directory_Entry_Attributes;
         Reserved           : Unsigned_8;
         Creation_Seconds   : Unsigned_8;
         Creation_Time      : Unsigned_16;
         Creation_Date      : Unsigned_16;
         Last_Accessed_Date : Unsigned_16;
         First_Cluster_High : Unsigned_16;
         Last_Modified_Time : Unsigned_16;
         Last_Modified_Date : Unsigned_16;
         First_Cluster_Low  : Unsigned_16;
         File_Size          : Unsigned_32;
      end record
   with Size => 256;
   for Directory_Entry use
      record
         File_Name          at 0 range 0   .. 87;
         Attributes         at 0 range 88  .. 95;
         Reserved           at 0 range 96  .. 103;
         Creation_Seconds   at 0 range 104 .. 111;
         Creation_Time      at 0 range 112 .. 127;
         Creation_Date      at 0 range 128 .. 143;
         Last_Accessed_Date at 0 range 144 .. 159;
         First_Cluster_High at 0 range 160 .. 175;
         Last_Modified_Time at 0 range 176 .. 191;
         Last_Modified_Date at 0 range 192 .. 207;
         First_Cluster_Low  at 0 range 208 .. 223;
         File_Size          at 0 range 224 .. 255;
      end record;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------
   type Directory_Index is array (Natural range <>) of Directory_Entry;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------
   type Long_File_Name_String is array (Natural range <>) of Wide_Character;

   type Long_File_Name_Sequence is
      record
         Number     : Unsigned_5;
         Empty_1    : Boolean := False;
         Last_Entry : Boolean;
         Empty_2    : Boolean := False;
      end record;
   for Long_File_Name_Sequence use
      record
         Number     at 0 range 0 .. 4;
         Empty_1    at 0 range 5 .. 5;
         Last_Entry at 0 range 6 .. 6;
         Empty_2    at 0 range 7 .. 7;
      end record;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------
   type Long_File_Name_Directory_Entry is
      record
         Sequence      : Long_File_Name_Sequence;
         Name_1        : Wide_String (1 .. 5);
         Attributes    : Directory_Entry_Attributes;
         Entry_Type    : Unsigned_8;
         Checksum      : Unsigned_8;
         Name_2        : Wide_String (1 .. 6);
         First_Cluster : Unsigned_16;
         Name_3        : Wide_String (1 .. 2);
      end record
   with Size => 256;
   for Long_File_Name_Directory_Entry use
      record
         Sequence      at 0 range 0   .. 7;
         Name_1        at 0 range 8   .. 87;
         Attributes    at 0 range 88  .. 95;
         Entry_Type    at 0 range 96  .. 103;
         Checksum      at 0 range 104 .. 111;
         Name_2        at 0 range 112 .. 207;
         First_Cluster at 0 range 208 .. 223;
         Name_3        at 0 range 224 .. 255;
      end record;

   ----------------------------------------------------------------------------
   --  An entry into a FAT32 formatted table.
   ----------------------------------------------------------------------------
   type FAT32_Table_Entry is new Unsigned_32;

   ----------------------------------------------------------------------------
   --  The file allocation table in a FAT32 formatted device.
   ----------------------------------------------------------------------------
   type FAT32_Table is
     array (Natural range <>) of aliased FAT32_Table_Entry
     with Pack;

   ----------------------------------------------------------------------------
   --  Get_Filesystem_Type
   --
   --  Purpose:
   --    Gets the type of a FAT filesystem.
   ----------------------------------------------------------------------------
   procedure Get_Filesystem_Type (
     Boot_Sec :     Boot_Sector;
     FAT_Type : out FAT_Type_T;
     Status   : out Program_Status
   );

   ----------------------------------------------------------------------------
   --  Parse_Directory
   ----------------------------------------------------------------------------
   procedure Parse_Directory (
     Directory_Buffer_Addr : System.Address;
     Directory_Size        : Natural;
     Status                : out Program_Status
   );

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------
   function Dir_Entry_To_LFN_Dir_Entry is
      new Ada.Unchecked_Conversion (
        Source => Directory_Entry,
        Target => Long_File_Name_Directory_Entry
      );
end Cxos.Filesystems.FAT;
