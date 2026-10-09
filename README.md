# omnibook-atamem

A ROM card patch for the HP OmniBook 425 that lets any PC Card ATA or
CompactFlash card run in memory mode, in the internal C: drive slot and in
the two user slots.

## TL;DR

- Stock 425: only HP's SanDisk flash cards get memory mode. Any other ATA or
  CF card as C: runs in 16-bit I/O mode, and 8-bit sound and MIDI cards in
  the user slots then lose their odd registers.
- The patch: up to 65 bytes in OBCBIOS, the PC Card module on the ROM card,
  in five selectable parts. Non-SanDisk ATA/CF cards then run in memory
  mode, cards of 4GB and up work with a 2GB partition, and the 8-bit cards
  work beside them. Card results are in [doc/CARDS.md](doc/CARDS.md).
- How: dump your ROM card, run `obpatch.py` (modern machine) or `OBPATCH.COM`
  (DOS, 386+) on the image, and write it to a linear flash card such as a
  PRETEC FR2016 on another machine with
  [LINGO](https://github.com/zikolas/lingo). The 425 cannot write the ROM
  card it runs from.
- Cards: MBR, one active FAT12/FAT16 partition (type 01 or 06), 2GB or
  smaller.
- Option 6, separate and optional: a 4-byte patch to `C:\OBMGM.COM` that
  stops the "Unrecognized Plug-in Card" popup. It runs on the 425.

This patch is experimental and has seen limited testing: one OmniBook 425,
one ROM card build, one card booted as C: in memory mode, and 15 cards tried
in a user slot. It changes the firmware the 425 runs at power-on. Keep your
original HP ROM card and an unmodified dump of it, and use the patch at your
own risk.

On a stock 425 only HP's own SanDisk-made flash disks get memory mode. Every
other ATA card in the C: slot is driven in 16-bit I/O mode at 1F0h/3F6h, and
while that I/O window is live the odd-numbered registers of 8-bit cards in
the user slots float (UART line status, scratch registers, gameport). Larger
SanDisk cards are worse off: they get memory mode with a size of zero and the
drive is unusable.

The patch changes up to 65 bytes, in five selectable parts, inside OBCBIOS,
the PC Card module the 425 BIOS loads from the ROM card at power-on. With it,
a non-SanDisk C: drive runs in memory mode, no I/O window is left in the C:
slot, and 8-bit sound and MIDI cards work beside it.

Tested on a 425 with a 128MB CompactFlash C: drive in memory mode, an EXP
GAME/MIDI card in a user slot (scratch register, line status and MIDI out to a
CM-32L all working), and 15 cards in a user slot (see
[doc/CARDS.md](doc/CARDS.md)).

## What you need

- An OmniBook 425 and its ROM card (US English `1.1S ABA` or UK English
  `1.1S ABB`; both carry the same OBCBIOS and are supported).
- A dump of that ROM card as an image file, and a linear flash card the 425
  accepts in its ROM slot to write the patched image to. The PRETEC
  FR2016 (16MB, Intel 28F008SA flash) is known to boot the 425.
  [LINGO](https://github.com/zikolas/lingo) reads and writes both.
  LINGO's [OmniBook notes][lingo-ob] cover which flash cards boot the 425,
  how to read the card size from its header, and how to dump and clone it.
- Python 3, or a DOS machine with a 386 or later, to run the patcher.

The patcher contains no HP code. It works only on an image you dump from
your own ROM card, and it refuses anything that is not the exact OBCBIOS
build it was written for.

## Patching

The patch has five parts. Pick the ones you want; all five is the
combination tested on hardware.

| # | Name | What it does | Who needs it | Cost |
|---|---|---|---|---|
| 1 | anycard | memory mode for every card maker, not only SanDisk | any non-SanDisk card | none known |
| 2 | sectors63 | fixes HP's IDENTIFY check, which tests sectors/track instead of the error bit | cards with 63 sectors per track (most CF cards from 64MB, SanDisk included) | none |
| 3 | sizecap | caps the recorded card size just under 2GB | cards of 4GB and up | none: DOS uses at most 2GB |
| 4 | nopowerdown | no idle power-down of cards | cards that hang after HP wakes them (Transcend) | cards draw more while idle |
| 5 | nosetfeatures | skips HP's SanDisk SET FEATURES commands | IBM Microdrive | unknown effect on SanDisk power saving |

Parts 1 to 3 are what most people want. Add 4 and 5 if you use those cards.

On a modern machine (writes a new file, never touches the input):

    python3 patcher/obpatch.py ROM425.IMG ROM425-P.IMG
    python3 patcher/obpatch.py --without nopowerdown,nosetfeatures ROM425.IMG ROM425-P.IMG
    python3 patcher/obpatch.py --only anycard,sectors63 ROM425.IMG ROM425-P.IMG
    python3 patcher/obpatch.py --list
    python3 patcher/obpatch.py --check ROM425-P.IMG

On DOS, OBPATCH is interactive: toggle parts 1-5, H for help, P to patch,
Q to quit. It patches the file in place, so copy it first, and asks Y/N
naming the parts before it writes.

    OBPATCH ROM425.IMG

Both patchers find OBCBIOS through the ROM card's own directory, refuse
anything but the stock 425 module (CRC-32 590D344E), and check the result
against the known CRC of the chosen combination (all five: A5D494AD; the US
1.1S ABA image then has CRC-32 E7DE320B). On an image that is already patched
they report which parts it has. To change the selection, start again from the
original dump. OmniBook 300 and 430 cards carry a different OBCBIOS and are
refused.

The ROM card cannot be rewritten in the 425 itself. The 425 runs its BIOS and
ROM DOS directly from that card, the Intel flash cards that boot it need 12V
to program, and no OmniBook slot is known to supply it. Dump, patch and write
the card on another machine with a standard PC Card controller (for example
an IBM PC110 with LINGO; see "Cloning a card" in LINGO's
[OmniBook notes][lingo-ob-clone]), then move it to the 425. Keep the original
HP ROM card: swapping it back restores the stock machine.

## Cards that work

With the patch, a card works as a drive when its partition layout suits the
425:

- an MBR partition table (not GPT),
- one FAT12 or FAT16 partition, type 01 or 06 (types 07, 0E and EE are
  refused), 2GB or smaller,
- the partition marked active (boot flag 80h); without it HP's software
  pops up "Unrecognized" and the slot stays dead,
- a DOS-style boot sector. A FAT16 volume with 6 reserved sectors and 255
  heads (a later-Windows layout) was rejected with "Invalid media type"; the
  same card reformatted with 1 reserved sector works.

FAT32, exFAT and GPT cards need repartitioning and a FAT16 format first.
Cards larger than 2GB work with a 2GB partition at the start.

## Option 6: no "Unrecognized Plug-in Card" popup

A separate, optional patch for `C:\OBMGM.COM`, the HP message manager that
shows a popup when a card it does not know is inserted. With third-party
sound, MIDI or serial cards and their enablers, that popup comes up on every
insertion even though the card works. Option 6 (`nopopup`) changes 4 bytes so
OBMGM skips that one message; its other messages stay. It is a file on C:,
not part of the ROM card, so it can be applied with or without the ROM patch.

Unlike the ROM card, this file can be patched on the 425 itself. Copy
OBPATCH.COM to the 425 (for example on a CF card in a user slot), back up
OBMGM.COM and run OBPATCH there:

    COPY C:\OBMGM.COM C:\OBMGM.ORG
    OBPATCH C:\OBMGM.COM

OBPATCH asks Y/N before it writes, then patches the file in place. Reboot to
load the new copy. Alternatively, copy OBMGM.COM to a modern machine,
patch it there and copy the result back to C:\:

    python3 patcher/obpatch.py OBMGM.COM OBMGM-P.COM

Both patchers accept only OBMGM 1.03 (22,341 bytes, CRC-32 8AAE549B; patched
2F9D6F3B). To undo it, copy your backup (or `OBMGM.COM` from
D:) back to C:\. With the patch, a card HP rejects shows no message; the
slot just stays empty.

Setting a card up as C: (HP's first-boot format prompt, OBSETUP, and the
OBBOOT settings that turn the Flash File System and DoubleSpace on and off)
is covered in [doc/C-DRIVE.md](doc/C-DRIVE.md).

## What the patch changes

| Part | Module offset | Change |
|---|---|---|
| 1 anycard | 2E57h, 2E61h | Allow memory mode for every manufacturer, not only SanDisk (MANFID 0045). |
| 2 sectors63 | 2D58h | HP's check after IDENTIFY tests bit 0 of sectors/track instead of the ATA error bit, so every card with 63 sectors per track got size 0. |
| 3 sizecap | 2D1Fh-2D4Fh, 2F9Ah-2FA9h | Rewrite the IDENTIFY geometry read more compactly, add a clamp, and cap the recorded size just under 2GB. HP's 32-bit size wraps on large cards and HP checks every access against it. |
| 4 nopowerdown | 2BF4h | Stop setting the card's power-down bit after 5 seconds idle. Some cards (Transcend) stay busy after HP wakes them. |
| 5 nosetfeatures | 2DBAh | Skip two SanDisk vendor SET FEATURES commands (69h, 97h). An IBM Microdrive aborts every media command after them. |
| 6 nopopup | OBMGM.COM file offset 4AE5h | Send the two "Unrecognized Plug-in Card" cases of OBMGM's message selector to its exit. |

The full analysis, with the evidence for each change, is in
[doc/FINDINGS.md](doc/FINDINGS.md). The DOS probes used for the work are in
[tools/](tools/).

## Status

Version 1.1 (obpatch.py and OBPATCH 1.1), experimental. 1.1 adds option 6.
Known gaps:

- The German `1.1S ABD` card is untested. The patcher checks the module CRC
  and will refuse it if it differs.
- Only a 128MB card has been booted as C: in memory mode so far, with all
  five parts. Larger cards were tested in a user slot, where the same
  OBCBIOS code runs.
- Combinations other than all five have been checked byte for byte between
  the Python and DOS patchers but not booted.
- Option 6 has been tested on one 425 with one card: OBPATCH 1.1 patched
  C:\OBMGM.COM on the 425, and after a reboot an SCP-55 removed and
  re-inserted with the machine on gave no popup and still enabled with
  SCP55GO.
- HP's per-sector error check during reads and writes can never fire (it
  uses `test` and then `jc`). A sector the card reports as bad reaches DOS
  as data. The patch does not change this.

## License

MIT, see [LICENSE](LICENSE). HP's ROM card contents remain HP's; this
project distributes only the patch.

[lingo-ob]: https://github.com/zikolas/lingo/blob/main/doc/OMNIBOOK.md
[lingo-ob-clone]: https://github.com/zikolas/lingo/blob/main/doc/OMNIBOOK.md#cloning-a-card
