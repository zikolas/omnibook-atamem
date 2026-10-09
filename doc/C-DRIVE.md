# Setting up a CompactFlash or ATA card as C: on the 425

The 425 splits its system across two drives. D: is the ROM card (DOS,
Windows and HP's applications, read through the Microsoft Flash File
System); C: is the card in the internal drive slot and holds CONFIG.SYS,
AUTOEXEC.BAT and your files. HP shipped C: as a DoubleSpace-compressed flash
disk or hard disk. A larger CF card does not need compression, and running
it uncompressed frees memory.

## Preparing the card

The card needs the layout described in the README under "Cards that work":
an MBR with one active FAT16 (type 06) or FAT12 (type 01) partition, 2GB or
smaller. Without the patch, it also has to be a card the stock ROM drives
correctly (see [CARDS.md](CARDS.md)).

## First boot: answer N

With a blank or new card as C:, the 425 boots from D: and asks:

    Do you want to format drive C: and copy required files (Y/N)? [Y]

The default Y runs HP's full preparation, which sets up DoubleSpace on the
card. To keep the card uncompressed, answer N, then from D::

    FORMAT C:
    D:\OBSETUP /F

`OBSETUP /F` copies the system files to C: without creating DoubleSpace.
Run FDISK first only if the card has no partition.

## OBBOOT: choosing what loads at boot

`OBBOOT.COM` (on D:, and on C: after setup) sets the boot drive and which of
the two drivers the 425 loads. Its parameter is a drive letter (A, B or C)
followed by an option digit (0 to 3); either part can be given alone and the
other keeps its current value. With no parameter it shows the current
setting. The setting is kept in the machine's CMOS RAM, not in CONFIG.SYS,
and the 425 reboots as soon as it is changed. `OBBOOT C3` means: boot from
C:, DoubleSpace off, Flash File System off.

| Command | Flash File System (D:) | DoubleSpace | Use |
|---|---|---|---|
| `OBBOOT C0` | on | on | factory setting; D: available |
| `OBBOOT C1` | off | on | DoubleSpace-compressed C:, more memory (about 535K) |
| `OBBOOT C2` | on | off | D: available with an uncompressed C: |
| `OBBOOT C3` | off | off | uncompressed C:, most memory (about 580K) |

The options are as listed in OBBOOT's own help; the memory figures are from
HP's `BOOTDOS.BAT`. On the test machine C3 gave a largest executable program
of 593,024 bytes (579K) with nothing else loaded.

Notes:

- C2 and C3 need an uncompressed C:. On a DoubleSpace card, C2 shows the raw
  host drive instead of your files. With C3 the boot from C: fails; the 425
  then sets OBBOOT back to C0 by itself and reboots from D:, reporting
  "Drive C does not contain a recognizable mass storage device".
- In C1 and C3 there is no D:. Copy anything you still need from D: first
  (OBBOOT.COM itself, MEM, CHKDSK and so on), and switch back to C0 when you
  need D:.
- HP's `BOOTDOS.BAT` runs `OBBOOT C1` but first copies `CONFIG.DOS` and
  `AUTOEXEC.DOS` over your CONFIG.SYS and AUTOEXEC.BAT. To change only the
  boot setting, run `OBBOOT` directly.
- To see the current setting, run `OBBOOT` with no parameters. The comment
  at the top of a CONFIG.SYS is no evidence of it.
- `OBMGM.COM`, loaded from CONFIG.SYS, shows HP's card popups. Option 6 in
  the README removes its "Unrecognized Plug-in Card" popup.

## With the patch

The patched OBCBIOS sets C: up at power-on, before DOS and before either
driver loads, so a memory-mode C: works with any OBBOOT setting. For a
CompactFlash C: the usual choice is C3: no DoubleSpace on the card and the
most conventional memory.
