with System.Storage_Elements;

package body x86.IDT is
   use System.Storage_Elements;

   ----------------------------------------------------------------------------
   --  Initialise
   ----------------------------------------------------------------------------
   procedure Initialise is
   begin
      Initialise_Loop :
         for I in Descriptor_Entry_Range range 0 .. IDT_LENGTH loop
            Initialise_Descriptor (I);
         end loop Initialise_Loop;
   end Initialise;

   ----------------------------------------------------------------------------
   --  Initialise_Descriptor
   --
   --  Implementation Notes:
   --    - Zeroes out an individual descriptor entry.
   ----------------------------------------------------------------------------
   procedure Initialise_Descriptor (
      Index : Descriptor_Entry_Range
   ) is
   begin
      Interrupt_Descriptor_Table (Index).Offset_Low  := 0;
      Interrupt_Descriptor_Table (Index).Offset_High := 0;
      Interrupt_Descriptor_Table (Index).Selector    := 0;
      Interrupt_Descriptor_Table (Index).Descr_Type  := Interrupt_Gate_32_Bit;
      Interrupt_Descriptor_Table (Index).S          := False;
      Interrupt_Descriptor_Table (Index).DPL         := Ring_0;
      Interrupt_Descriptor_Table (Index).P           := False;

   exception
      when Constraint_Error =>
         return;
   end Initialise_Descriptor;

   ----------------------------------------------------------------------------
   --  Install_Descriptor
   ----------------------------------------------------------------------------
   procedure Install_Descriptor (
     Index       : Descriptor_Entry_Range;
     Offset_Addr : System.Address;
     Selector    : Descriptor_Entry_Range;
     Privilege   : Descriptor_Privilege_Level := Ring_0
   ) is
   begin
      --  Set the descriptor's offset fields.
      --  If an overflow occurs here the procedure will exit.
      Set_Descriptor_Offset :
         declare
            Offset : constant Unsigned_32 :=
              Unsigned_32 (To_Integer (Offset_Addr));
         begin
            Interrupt_Descriptor_Table (Index).Offset_Low :=
              Unsigned_16 (Offset and 16#FFFF#);
            Interrupt_Descriptor_Table (Index).Offset_High :=
              Unsigned_16 (Shift_Right (Offset, 16) and 16#FFFF#);
         exception
            when Constraint_Error =>
               return;
         end Set_Descriptor_Offset;

      Interrupt_Descriptor_Table (Index).Selector   := Unsigned_16 (Selector);
      Interrupt_Descriptor_Table (Index).Descr_Type := Interrupt_Gate_32_Bit;
      Interrupt_Descriptor_Table (Index).S          := False;
      Interrupt_Descriptor_Table (Index).DPL        := Privilege;
      Interrupt_Descriptor_Table (Index).P          := True;

   exception
      when Constraint_Error =>
         return;
   end Install_Descriptor;
end x86.IDT;
