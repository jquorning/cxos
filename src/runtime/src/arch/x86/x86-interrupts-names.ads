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

with Ada.Interrupts; use Ada.Interrupts;

-------------------------------------------------------------------------------
--  Ada.Interrupts.Names
--
--  Purpose:
--    Contains the names for system interrupts.
-------------------------------------------------------------------------------
package x86.Interrupts.Names is
   pragma Preelaborate;

   IRQ0  : constant Interrupt_ID := 0;
   IRQ1  : constant Interrupt_ID := 1;
   IRQ2  : constant Interrupt_ID := 2;
   IRQ3  : constant Interrupt_ID := 3;
   IRQ4  : constant Interrupt_ID := 4;
   IRQ5  : constant Interrupt_ID := 5;
   IRQ6  : constant Interrupt_ID := 6;
   IRQ7  : constant Interrupt_ID := 7;
   IRQ8  : constant Interrupt_ID := 8;
   IRQ9  : constant Interrupt_ID := 9;
   IRQ10 : constant Interrupt_ID := 10;
   IRQ11 : constant Interrupt_ID := 11;
   IRQ12 : constant Interrupt_ID := 12;
   IRQ13 : constant Interrupt_ID := 13;
   IRQ14 : constant Interrupt_ID := 14;
   IRQ15 : constant Interrupt_ID := 15;
end x86.Interrupts.Names;
