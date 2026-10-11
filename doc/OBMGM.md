# OBMGM: the OmniBook Message Manager

`OBMGM.COM` (version 1.03 on the 425, 22,341 bytes) is a resident program
that HP's CONFIG.SYS loads from C: with `install=`. It shows HP's messages
and status on screen and handles a few hardware settings. This page lists
what it does, as far as its own messages and the ROM show, so you can judge
what you give up by leaving it out (option 7 in the README) and what option
6 changes.

## What it does

| Job | Its own wording | Without OBMGM |
|---|---|---|
| Power status | AC/battery indicator in the top right corner of the screen | No power display. |
| Low battery | "Low Battery! The computer will turn off in 2 minutes or less. You should connect the AC adapter or install charged batteries." | No warning before the 425 turns itself off on battery. |
| Battery fault | "Battery Pack Problem: The battery pack is unable to accept a charge." | Not reported. |
| Password | "Enter Password", "Incorrect Password" | Probably the password check when the 425 wakes from sleep. Whether the BIOS still asks at power-on without OBMGM has not been tested. |
| Alarms | "Appointment Reminder" | Alarms from HP's appointment book do not pop up. |
| RAM card battery | "Low RAM Card Battery! The battery in the RAM card in drive A (B) is low." | No warning; an SRAM card loses its data when its battery runs out. |
| Unknown cards | "Unrecognized Plug-in Card: The plug-in card in slot A (B) is not recognized." | No popup (option 6 removes only this one). |
| Modem cards | "Too Many Modem Cards: The modem card in slot A is currently the only one you can use." | No popup. |
| Power management | "The power management option has been changed to Standard or Off. ... the computer will not turn off automatically." | No notice. |
| COM ports | "Serial port assigned to COM1", "Internal modem assigned to COM2", "Infrared port assigned to COM3", "Modem card (if present) assigned to COM4", and the reassigned forms ("Serial port is reassigned to COM4") | The ports keep their power-on assignment. Settings kept in `C:\OBMGM.DAT` are not applied. |

It also contains the name `TSI_Redirector`, which points to support for
Traveling Software's LapLink, the file transfer program HP shipped on the
ROM card.

## How it fits into the system

- It answers on the INT 2Fh multiplex interface (function 50h with BX =
  4C53h returns 4C53h). ROM DOS uses that after CONFIG.SYS to check that
  OBMGM is loaded and reboots from drive D if it is not; option 7 removes
  that check (FINDINGS section 14).
- It refuses to load while Windows is running and when no INT 2Fh
  multiplex number is free, and it reports when it is already installed.
- It hooks the ROM's CardBios entry (INT 1Ah AH=B0h) and writes VLSI
  controller registers 32h, 3Eh, 40h, 41h, 47h and 48h. What those writes
  do has not been worked out.
- In a test on an OmniBook 425 without OBMGM, COM1 worked, the 425 slept and
  woke with the power button, and about 20K more conventional memory was
  free.

## Choosing

- On battery, OBMGM is worth loading for the low-battery warning and the
  power display. Option 6 keeps it quiet about third-party PC Cards.
- On AC power, at a desk, or when a program needs the memory, option 7 lets
  CONFIG.SYS leave it out.

The two options can be combined: with both, a CONFIG.SYS for use on battery
can load OBMGM without the card popup, and another can leave it out.
