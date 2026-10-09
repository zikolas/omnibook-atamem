# Probes

DOS tools written for the investigation, for an HP OmniBook 425. Build each
with `nasm -f bin -o NAME.COM NAME.ASM`. Tools that save a file write it to
`C:\OBT\` (create the directory first).

Most borrow memory window 1, which the BIOS gives to the ROM drive (D:,
write-protected), point it at the card for a moment with interrupts off and
put it back. Do not run them while D: is in use.

| Tool | Reads or writes | What it does |
|---|---|---|
| VLWIN | reads | VLSI controller I/O window registers 1Eh-25h and socket control 34h-39h |
| SSSTAT | reads | Socket Services GetStatus for sockets 1-4 (present, ready, write-protect) |
| CISN n | reads | dumps socket n's attribute memory (CIS, config register at 200h) to `CISn.BIN` |
| ROMWIN xxxx | reads | maps window 1 at ROM card offset xxxx x 4K and saves the 16K to `ROMWIN.BIN` |
| MEMDUMP seg len | reads | saves seg:0000 for len bytes (hex, 0 = 64K) to `MEM.BIN` |
| IDENTN n | ATA IDENTIFY | IDENTIFY DEVICE on a memory-mode ATA card in socket n, saved to `IDENT.BIN` |
| READN n lba | ATA READ | reads one sector (LBA in hex) to `SECT.BIN` |
| ATAREGS n | reads | prints the card's task file registers (error, count, LBA, status) |
| POLLATA n | reads | prints ATA status and controller registers once a second for 40 seconds |
| ATAPWR n cc | ATA power command | issues one of E0h-E5h (standby, idle, check power mode) and prints the result |
| SIZECAP.ASM | | source of the size cap blocks in the patch (assembled at their module offsets) |

Useful OBCBIOS locations on a 425 with 622K base memory: module at 9C5D:0000,
data segment 9BC0, socket table at 9BC0:015C, region index at 9BC0:019A.
