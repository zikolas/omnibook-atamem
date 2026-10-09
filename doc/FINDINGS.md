# OmniBook 425: ATA cards, memory mode and the OBCBIOS patch

This is the full write-up behind the patch. Offsets are in the OBCBIOS
module unless marked "card" (ROM card offset) or "F000:" (the system BIOS
segment). Everything here was measured on a 425 over a serial link with the
read-only probes in [../tools](../tools), or read from the code those
measurements pointed at.

## 1. The problem

The 425 has three PC Card slots driven by a VLSI controller (index/data at
I/O ECh/EDh): two user slots and an internal one (socket 3) for the C:
drive. The ROM card sits in a fourth, internal socket.

On the bench machine the C: drive was a 128MB CompactFlash card in an
adapter. The BIOS drove it in I/O mode: I/O windows 4 and 5 mapped socket 3
at 1F0h-1F7h and 3F6h, and the socket 3 control register (34h) read 79h,
bit 0 set for a 16-bit data path. With that drive in place, an 8-bit card in
a user slot (EXP GAME/MIDI) lost its odd-numbered registers: 251h, 253h,
255h and 257h read 20h and writes vanished. Booted from HP's own 20MB SanDisk
flash disk instead, which the BIOS drives in memory mode with no I/O window,
the same card worked.

So the question was why one ATA card gets memory mode and another I/O mode,
and whether the choice can be changed.

## 2. Where the decision is made: OBCBIOS on the ROM card

The 425's F000 segment is the top 64K of the first 8MB of the ROM card (card
7F0000h-7FFFFFh; card 7F4000h reads the same as F000:4000). The system BIOS
runs from the ROM card, and the US and UK cards carry different F000 builds.

At POST, the loader (F000:BB46 on the US card, F000:BB56 on the UK card)
maps memory window 0 to socket 4 at card offset 7F4000h and searches a
directory of 16-byte entries downward from F000:7FF0 (card 7F7FF0h):
`{name[8], dword card offset, word length, word 0}`. On a US 1.1S ABA card:

| Name | Card offset | Length |
|---|---|---|
| BIOS0 | 800000h | 8000h |
| DOSHI | 808000h | 7000h |
| OBCBIOS | 80F000h | 3A2Bh |
| OBSMIBIN | 812A2Bh | 1188h |
| PRECONF0-3 | 813BB3h | |
| MRCI | 813C62h | 341Eh |
| MS-FLASH | 817080h | DB68h |
| DBLSPACE | 824BE8h | C614h |
| DSSWAP | 8311FCh | 03AFh |

The loader copies OBCBIOS to the top of the 18K reserve below 640K
(EBDA+480h-length; on the test machine segment 9C5Dh) and far-calls offset
0. Its data segment is EBDA+40h. The loader's only checks are its four
errors, "Error CB1" to "CB4" (map, find, size, init). It does not checksum
the module, which is why a patched module boots.

OBCBIOS hooks INT 1Ah (Socket Services AH=80h-9Ch plus the HP "CardBios"
entry AX=B000h) and INT 08h, reads each card's CIS, decides how to drive it
and keeps a table of socket entries (16 bytes each, pointer at data 0006h)
and region records (23h bytes each, index table at data 0018h). A region
record holds a next pointer at +0, the region size (dword) at +2 and the
region type at +10h: 20h for memory-mode ATA, 21h for I/O-mode ATA, 0Dh for
the DEVICE tuple region.

## 3. The memory-mode decision (3317h, 367Eh, 2DF5h)

For an ATA card, 3317h calls 367Eh, which reads FUNCID (must be 04h, fixed
disk), FUNCE, CONFIG and every CFTABLE entry and records which interfaces
the card offers: memory-mapped (interface type 0), I/O at 1F0h/3F6h, I/O at
170h/376h, contiguous I/O. It keeps the config index for each.

- If the card offers memory-mapped mode, 3317h calls 2DF5h to set it up.
  If 2DF5h returns 1 the card is in memory mode and nothing else happens.
- Otherwise, only for socket 3 and only if the card offers 1F0h/3F6h,
  3317h configures primary I/O mode (37DEh, mode 1).

2DF5h refuses memory mode unless:

1. MANFID (tuple 20h) is 0045h, SanDisk, with card ID low byte 01
   (2E52h `cmp word [0023h],45h`, 2E5Ch `cmp byte [0025h],1`), and
2. a DEVICE-tuple region of type 0Dh carries a JEDEC word (tuple 18h/19h) of
   0145h, 0245h, 01DFh, 02DFh, 04DFh or 08DFh (2E7Dh-2EABh).

That is the CIS fingerprint of SanDisk's SDP-family controllers. Every card
tested had DEVICE type 0Dh and JEDEC DF 01, so in practice the MANFID check
is what separates SanDisk from everyone else. Patches 5 and 6 turn those two
`jz` into `jmp`.

F000:8C4F (US; 8C55 on the UK card) runs after OBCBIOS and asks CardBios for
socket 3's regions. If it finds an I/O-mode ATA region (21h) it installs the
standard IDE INT 13h handler for drive 80h. If not, C: is served through the
CardBios region driver, the same path as the A: and B: drives in the user
slots.

## 4. Size 0 for any card with 63 sectors per track (2C64h)

After switching the card to memory mode, 2DF5h calls 2C64h to read the IDENTIFY
data and compute the region size from cylinders x heads x sectors. 2C64h
reads the IDENTIFY words, leaving sectors/track in AL, then:

    2D50  push ax / push dx
    2D52  call 2B1Fh        ; wait for BSY clear; returns without touching AL
                            ; when the card is not busy
    2D57  test al,1         ; meant as the ATA ERR bit; AL = sectors/track
    2D59  jz   ok
    2D5B  (error) size 0

With 63 sectors per track (every CompactFlash card from about 64MB up, and
SanDisk's own SDCFB/SDCFJ cards) the test sees an odd number and records size
0. The card is still in memory mode, so the drive is dead and does not fall
back to I/O mode. HP's own SDP5-10 reports 320/2/32 and passes; the SDP5-20
works as C: on a stock machine, so it passes too.

When the card is still busy at 2D52, 2B1Fh goes through 2AFAh, which loads
AL with a socket status value, so the outcome depends on timing. On the test
machine a SanDisk SDCFJ-512 in the C: slot came up with size 0 and "Not ready";
the BIOS then offered to format C:. (The same card model works as C: in an
OmniBook 530, which uses a different BIOS without OBCBIOS.)

Patch 3 changes the test to `test al,0`. The real ATA error bit was never
being checked here, so nothing is lost.

## 5. The read and write path (30E7h, 3142h, 2FC6h)

Memory-mode ATA regions (record +1Ah = 0Ah) dispatch to 30E7h for reads
(command 20h) and 3142h for writes (command 30h). 2FC6h sets up the access:

- the card byte address (32 bits at data 0127h) is shifted right by 9 to an
  LBA and written to the task file in LBA mode (drive/head E0h), so the
  cylinder count of the card does not matter;
- requests must be whole 512-byte sectors (errors 89h, 8Ah);
- BSY and DRDY are polled with a timeout of 221h ticks of the module's own
  INT 08h counter, about 30 seconds (error 8Bh).

The per-sector loops copy 256 words from window offset 400h and then test
the ATA status with `test byte [es:7],1` followed by `jc` (3114h, 3170h).
`test` always clears CF, so an error the card reports for a sector is never
seen and the data goes to DOS as if it were good. The patch does not change
this.

## 6. Idle power-down (1813h, 17E7h, 2B8Fh)

After every access 1813h marks the socket "power down pending" and starts a
5Bh-tick timer (about 5 seconds). On expiry the INT 08h path calls 2B8Fh,
which sets bit 2 (PwrDwn) of the card's Card Configuration and Status
Register (attribute 202h). On the next access 17E7h either cancels the
pending power-down or calls 0C71h(socket, 4) to restore power, and 2FC6h
clears the PwrDwn bit again before issuing the command.

A Transcend TS1GCF133 does not come back from this. Polled once a second,
it stayed ready (status 50h) for 40 seconds after insertion; the first
access after that idle period left it busy (status D0h) with the issued LBA
still in its registers. HP then waited out its 30-second timeout and DOS
reported "General failure"; a retry returned unrelated data. Stopping
1813h from scheduling the power-down did not help; stopping 2B8Fh from
setting the bit did. Patch 1 changes `or byte [es:bx],04h` at 2BF1h to
`or byte [es:bx],00h`. The cost is that no card is put into power-down when
idle.

## 7. SanDisk SET FEATURES at insertion (2D71h)

At the end of the memory-mode setup, 2D71h sends two SET FEATURES (EFh)
commands: feature 69h, then feature 97h with sector count 7Fh. These are
SanDisk vendor features. An IBM Microdrive (DSCM-11000) answered every media
command after them (READ SECTORS, IDLE IMMEDIATE) with status 51h, error 04h
(abort), while CHECK POWER MODE still worked. With both commands skipped it
spins up and reads normally. Patch 4 jumps over them (2DBAh `cmp` replaced by
`jmp short 2DDBh`).

A SanDisk SDCFB-1024 and HP's own SDP5-10 behave the same with or without
them in the tests run (mount, 40 seconds idle, full file reads). What they
did on the original SDP5 controllers could not be measured: CHECK POWER MODE
on the SDP5-10 reports 00h whether the features were sent or not.

## 8. Card size and the 2GB boundary (2F9Ah)

2F94h computes the region size as C x H x S x 512 in 32 bits. Cards with a
true size of 4GB or more wrap:

| Card | C x H x S x 512 | Recorded |
|---|---|---|
| Transcend 16GB (16383/15/63) | 1D8789E00h | D8789E00h (3.6GB) |
| Transcend 32GB (62041/16/63) | 7747CE000h | 747CE000h (1.95GB) |

HP checks every access against the recorded size. On the 32GB card with a
2GB FAT16 partition, a DOS absolute write (INT 26h) to partition sector
3FEF30h, beyond the wrapped size, failed with AX=0408h (sector not found),
while sector 2DC6C0h inside it worked. The 16GB card only worked because its
wrapped size happened to cover the partition.

Patches 2 and 7 add a clamp. Part A rewrites HP's IDENTIFY read at
2D1Fh-2D4Fh with `cld` and `es: lodsw` (same results: DX cylinders, AH
heads, AL sectors, all 256 words read), which frees 15 bytes for:

    2D40  cmp dl,40h         ; DX:AX = total sectors, DH = 0
          jb   done
          mov  dl,3Fh        ; cap at 3FFFFFh sectors
          or   ax,-1
    done: ret

Part B makes the size calculation at 2F9Ah `mul ah / mul dx / call 2D40h /
shld dx,ax,9 / shl ax,9` (386 instructions; the 425's CPU is a 486SLC). Any
card of 2GB or more is recorded as 7FFFFE00h. With it the 32GB card's write
to 3FEF30h worked and the data was at the expected LBA.

## 9. What HP's drive layer accepts

These limits sit above OBCBIOS and the patch leaves them alone:

| Layout | Result |
|---|---|
| MBR, active (80h), type 06 or 01 | works |
| active, type 07 | "Unrecognized" |
| active, type 0Eh (FAT16 LBA) | "Unrecognized" |
| inactive (00h), type 06 | "Unrecognized" |
| GPT (protective MBR, type EEh) | "Unrecognized" |
| FAT32 volume | "Invalid media type" |
| FAT16, 6 reserved sectors, 255 heads | "Invalid media type" |
| FAT16, 1 reserved sector, 16 heads | works |

DOS on the 425 handles FAT16 volumes up to 2GB (65,524 clusters of 32K);
that size was formatted, checked with CHKDSK and written to.

## 10. Result

On a 425 booted from a PRETEC FR2016 carrying the patched US image, with a
RiDATA 128MB CompactFlash card (MANFID 0000) as C::

| | Stock ROM card | Patched |
|---|---|---|
| C: mode | I/O, windows 4/5 at 1F0h/3F6h | memory mode, no I/O windows |
| socket 3 control (34h) | 79h | D8h |
| OBCBIOS socket 3 region | type 21h | type 20h, 07A40000h bytes |
| CHKDSK C: | | clean, 127,772,672 bytes |

With an EXP GAME/MIDI card inserted in socket 2 (8-bit I/O at 200h and
250h, on the windows 4/5 the C: drive no longer uses): scratch register 257h
read back 5Ah and A5h, LCR 03h, LSR 60h, gameport F0h, and a C major scale on
MIDI channel 2 played on a Roland CM-32L.

## 11. Patch summary

| Module offset | Card offset | Old | New |
|---|---|---|---|
| 2BF4h | 811BF4h | 04 | 00 |
| 2D1Fh-2D4Fh | 811D1Fh | 49 bytes (IDENTIFY read) | size cap part A |
| 2D58h | 811D58h | 01 | 00 |
| 2DBAh | 811DBAh | 80 7C | EB 1F |
| 2E57h | 811E57h | 74 | EB |
| 2E61h | 811E61h | 74 | EB |
| 2F9Ah-2FA9h | 811F9Ah | 16 bytes (size calc) | size cap part B |

The patchers apply these as five selectable parts (anycard = 2E57h + 2E61h,
sectors63 = 2D58h, sizecap = both size cap blocks, nopowerdown = 2BF4h,
nosetfeatures = 2DBAh); each of the 32 combinations has its own module CRC,
listed in the patchers. Module CRC-32: stock 590D344Eh, all five A5D494ADh. US 1.1S ABA image:
stock 9E447D28h, patched E7DE320Bh. The size cap source is
[../tools/SIZECAP.ASM](../tools/SIZECAP.ASM).

## 12. Writing the ROM card

The patched image cannot be written to the ROM card while it sits in the
425. The machine does not POST without an HP-compatible card in that slot:
its BIOS (the F000 segment) and ROM DOS run directly from the card, so
erasing a flash block, or switching the flash chips into their command and
status mode, would take the running code away. The Intel 28F008SA-class
cards known to boot the 425 also need 12V on Vpp to program, which no
OmniBook slot is known to supply, and Socket Services reports the ROM socket
write-protected (GetStatus DL=C1h).

Dump the original card, patch the image file and write the result on a
machine with a standard PC Card controller that supplies 12V (an IBM PC110
running LINGO was used here), then move the card to the 425. LINGO's
[OmniBook notes][lingo-ob] describe the ROM card's format, the cards known to
boot the 425 and the cloning procedure.

## 13. The "Unrecognized Plug-in Card" popup (OBMGM.COM)

The popup that appears when a card is inserted that HP's software does not
know comes from `OBMGM.COM`, the OmniBook message manager, which CONFIG.SYS
loads from C:. It is not part of OBCBIOS. Enablers for third-party cards
(sound, MIDI, serial) bring those cards up after the popup has been shown,
so on a 425 used with such cards it appears on every insertion.

OBMGM 1.03 (22,341 bytes, CRC-32 8AAE549Bh) picks a message with a
seven-way jump table (file offset 4AE5h, in memory 4BE5h). Cases 0 and 1
are the "Unrecognized Plug-in Card" message for the two user slots; the
others are HP's modem and card messages. Each case pushes a message
pointer and calls the display routine, then falls into the selector's exit
at 4C1Dh. Pointing cases 0 and 1 at the exit (`F8 4B FD 4B` to
`1D 4C 1D 4C`) drops only that message. The patched file has CRC-32
2F9D6F3Bh.

Tested on the 425, first by patching the resident copy in memory and then
by running OBPATCH 1.1 on C:\OBMGM.COM on the 425 itself and rebooting: no
popup on re-inserting the SCP-55 with the machine on, and SCP55GO still
brought the card up. Card
insertion is handled by Card Services, not by OBMGM, so cards are set up as
before. The only change is that a card HP rejects (for example a CF card
with an inactive or type 07 partition, section 9) no longer says so; the
slot just stays empty.

[lingo-ob]: https://github.com/zikolas/lingo/blob/main/doc/OMNIBOOK.md
