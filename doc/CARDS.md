# Cards tested

All cards were tested in user slot 1 (drive A:) of an OmniBook 425 with the
patched OBCBIOS active in RAM, and read with the probes in
[../tools](../tools). "Stock" says what the unpatched ROM card would do with
the card in the C: slot, worked out from its CIS and IDENTIFY data. Only the
SanDisk SDCFJ-512 was booted as C: on the stock ROM card to confirm it.

Patch parts: ID = MANFID gate (patches 5, 6), S63 = sectors/track test
(patch 3), PD = idle power-down (patch 1), SF = SET FEATURES skip
(patch 4), CAP = size cap (patches 2, 7).

| Card | MANFID | CHS (IDENTIFY) | Stock as C: | Patch parts used | Result |
|---|---|---|---|---|---|
| SunDisk SDP5-10 (HP 10MB flash disk) | 0045/0401 | 320/2/32 | memory mode | none | works |
| SunDisk SDP5-20 (HP 20MB flash disk) | 0045/0401 | not read | memory mode (measured) | none | works as C: |
| SanDisk 128MB, CIS "SunDisk SDP 5/3 0.6" | 0045/0401 | not read (even) | memory mode | none | works |
| SanDisk SDCFH-256 | 0045/0401 | 980/16/32 | memory mode | none | FAT32 on the card: needs FAT16 |
| SanDisk SDCFJ-512 | 0045/0401 | 993/16/63 | memory mode, size 0 (measured: C: not ready) | S63 | works |
| SanDisk SDCFB-1024 | 0045/0401 | 1986/16/63 | memory mode, size 0 | S63 | works |
| Lexar ATA flash card 512MB | 4E01 | 994/16/63 | I/O mode | ID, S63 | works |
| SMART (Toshiba THNCF512MDG controller) 512MB | 0098 | 993/16/63 | I/O mode | ID, S63 | works |
| SMART Modular "SMART 223" 2GB | 947F/0007 | 3787/16/63 | I/O mode | ID, S63 | works |
| RiDATA CF-ATA 128MB | 0000/0000 | not read | I/O mode (measured) | ID | works as C: in memory mode (patched ROM card) |
| Transcend TS1GCF133 1GB | 004F | 1942/16/63 | I/O mode | ID, S63, PD | works |
| IBM Microdrive DSCM-11000 1GB | 00A4 | 2088/16/63 | I/O mode | ID, S63, SF | works after reformatting (see FINDINGS 9) |
| STEC (CIS "STI Flash 8.0.0") 2GB | 014D/0100 | 3970/16/63 | I/O mode | ID, S63 | FAT32 Windows 95 card, not reformatted |
| Transcend TS16GCF170 16GB | 00F1/0101 | 16383/15/63 | I/O mode | ID, S63 | works with a 2GB FAT16 partition |
| Transcend TS32GCF133 32GB | 00F1/0101 | 62041/16/63 | I/O mode | ID, S63, CAP | works with a 2GB FAT16 partition |
| Hitachi 4GB microdrive (from an iPod mini) | | | | | never ready in the slot |

Every card had DEVICE type 0Dh, JEDEC DF 01 and a memory-mapped CFTABLE entry
(index 0), so with the MANFID gate removed they all reach memory mode.

Cards in I/O mode as C: on a stock machine leave a 16-bit I/O window open,
which makes 8-bit cards in the user slots lose their odd registers. The
I/O-mode IDE path also addresses the drive by cylinder, head and sector, so
cards with more than 1024 cylinders are likely limited to about 500MB as C:
there (not tested).

## Hard disks in the C: slot

These were booted as C: and checked with VLWIN (socket 3 control register
34h: 79h or 7Dh = bit 0 set, a 16-bit I/O window at 1F0h/3F6h). On the 430
ROM card the extra bit 2 in 7Dh is the shared 12V Vpp switch, not width.

| Drive | Stock 425 ROM card | Patched 425 ROM card | 430 ROM card |
|---|---|---|---|
| Maxtor MXL-105-III (HP's 105MB 430 option, 810/15/17) | 16-bit I/O, boots | 16-bit I/O, boots | 16-bit I/O, works |
| Maxtor 131MB (from an OmniBook 530) | 16-bit I/O, works | not tried | 16-bit I/O, works |
| OmniBook 600 drive | 16-bit I/O, works | not tried | not tried |

None of them reached memory mode, and none ran 8-bit, so every one leaves
the odd-register problem in place. Their CIS could not be read in the C:
slot (the socket returns a constant byte once HP has set it up), so which
memory-mode gate they fail is not known yet. Reading them from a user slot
is the next step.

The MXL-105-III has 17 sectors per track, an odd count. HP's memory-mode
IDENTIFY check (FINDINGS section 4) would give it size 0; its I/O-mode
path does not have that bug, so the drive works.

The Hitachi microdrive reported "present, not ready" (Socket Services
GetStatus DL=80h) and never answered; no ROM code runs for it. Whether that
comes from its iPod firmware or from the slot's spin-up current is not known.
