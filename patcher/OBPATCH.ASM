; OBPATCH.COM - interactive DOS version of obpatch.py. Patches the OBCBIOS
; module of an HP OmniBook 425 ROM card image IN PLACE so ATA/CompactFlash
; cards run in memory mode, with each of the five patches selectable.
;
;   OBPATCH ROMCARD.IMG
;
; Finds OBCBIOS through the card's directory, needs the stock module
; (CRC-32 590D344E), recognises already patched images, asks before writing
; and checks the result against the known CRC for the chosen combination.
;
; Build: nasm -f bin -o OBPATCH.COM OBPATCH.ASM        (runs on a 386 or later)
; Test builds: -DTESTMASK=n patches combination n (bit mask 1-31) without
; prompts; -DDIR_TOP=x -DDIR_FLOOR=y moves the directory search for small
; stand-in images. Release builds use neither.
        cpu 386
        org 100h

%ifndef DIR_TOP
DIR_TOP   equ 7F7FF0h
DIR_FLOOR equ 7F4000h
%endif
MOD_LEN   equ 3A2Bh
NOPT      equ 5

start:
        mov  si, 81h                  ; filename -> fname (ASCIIZ + '$')
.sk:    lodsb
        cmp  al, ' '
        je   .sk
        cmp  al, 13
        je   usage
        mov  di, fname
.cp:    stosb
        lodsb
        cmp  al, ' '
        je   .end
        cmp  al, 13
        jne  .cp
.end:   mov  byte [di], 0
        mov  [fnend], di

        mov  dx, m_title
        call say
        mov  ax, 3D02h                ; open read/write
        mov  dx, fname
        int  21h
        jc   e_open
        mov  [handle], ax

        mov  dword [dirpos], DIR_TOP  ; walk the directory downward
.dir:   mov  eax, [dirpos]
        cmp  eax, DIR_FLOOR
        jb   e_nomod
        call seek
        jc   e_nomod
        mov  cx, 16
        mov  dx, ent
        call read
        jc   e_nomod
        cmp  byte [ent], 0
        je   e_nomod
        mov  si, ent
        mov  di, modname
        mov  cx, 8
        repe cmpsb
        je   .found
        sub  dword [dirpos], 16
        jmp  .dir
.found:
        mov  eax, [ent+8]
        mov  [modoff], eax
        cmp  word [ent+12], MOD_LEN
        jne  e_len
        call seek
        jc   e_read
        mov  cx, MOD_LEN
        mov  dx, buf
        call read
        jc   e_read
        call crcbuf                   ; which combination is this?
        mov  si, crctab
        xor  bx, bx
.lk:    cmp  eax, [si]
        je   .known
        add  si, 4
        inc  bx
        cmp  bx, 32
        jb   .lk
        jmp  e_crc
.known: or   bx, bx
        jz   .stock
        mov  dx, m_already            ; already patched: list and stop
        call say
        mov  [mask], bl
        call saynames
        mov  dx, m_redo
        jmp  close0
.stock:
        mov  dx, m_stock
        call say
        call sayfile
        mov  dx, crlf
        call say

%ifdef TESTMASK
        mov  byte [mask], TESTMASK
        jmp  dopatch
%else
menu:   call cls
        mov  dx, m_title
        call say
        mov  dx, m_stock
        call say
        call sayfile
        mov  dx, crlf
        call say
        mov  dx, crlf
        call say
        xor  bx, bx                   ; print the five option lines
.ol:    mov  dx, m_o1
        mov  ax, bx
        imul ax, OLEN
        add  dx, ax
        mov  di, dx
        mov  al, ' '
        bt   [mask], bx
        jnc  .off
        mov  al, 'x'
.off:   mov  [di+4], al
        call say
        inc  bx
        cmp  bx, NOPT
        jb   .ol
        mov  dx, m_keys
        call say
.key:   mov  ah, 0
        int  16h
        cmp  al, '1'
        jb   .let
        cmp  al, '5'
        ja   .let
        sub  al, '1'
        movzx bx, al
        btc  [mask], bx
        jmp  menu
.let:   and  al, 0DFh
        cmp  al, 'Q'
        je   e_quit
        cmp  al, 'H'
        je   .help
        cmp  al, 'P'
        jne  .key
        mov  dx, crlf
        call say
        cmp  byte [mask], 0
        jne  .ask
        mov  dx, m_none
        call say
        jmp  .key
.help:  call cls
        mov  dx, m_help
        call say
        mov  ah, 0
        int  16h
        jmp  menu
.ask:   mov  dx, m_ask1
        call say
        call sayfile
        mov  dx, m_ask2
        call say
        call saynames
        mov  dx, m_ask3
        call say
.yn:    mov  ah, 0
        int  16h
        and  al, 0DFh
        cmp  al, 'N'
        je   menu
        cmp  al, 'Y'
        jne  .yn
%endif

dopatch:
        mov  si, patches              ; {byte opt, word off, n, has-old, ...}
.p:     lodsb
        cmp  al, 0FFh
        je   .pd
        movzx bx, al
        lodsw
        mov  di, buf
        add  di, ax
        lodsb
        movzx cx, al
        lodsb
        mov  dl, al                   ; has-old flag
        bt   [mask], bx
        jc   .apply
        or   dl, dl                   ; skip this entry's data
        jz   .skipnew
        add  si, cx
.skipnew:
        add  si, cx
        jmp  .p
.apply: or   dl, dl
        jz   .new
        push cx
        push di
        repe cmpsb
        pop  di
        pop  cx
        jne  e_old
.new:   rep  movsb
        jmp  .p
.pd:
        call crcbuf
        movzx bx, byte [mask]
        shl  bx, 2
        cmp  eax, [crctab+bx]
        jne  e_int
        mov  eax, [modoff]
        call seek
        jc   e_write
        mov  ah, 40h
        mov  bx, [handle]
        mov  cx, MOD_LEN
        mov  dx, buf
        int  21h
        jc   e_write
        cmp  ax, MOD_LEN
        jne  e_write
        mov  ah, 3Eh
        mov  bx, [handle]
        int  21h
        jc   e_write
        mov  dx, m_ok
        call say
        call saynames
        mov  dx, m_lingo
        jmp  out0

; --- helpers --------------------------------------------------------------
seek:                                 ; EAX = file offset -> CF
        mov  dx, ax
        shr  eax, 16
        mov  cx, ax
        mov  ax, 4200h
        mov  bx, [handle]
        int  21h
        ret
read:                                 ; CX bytes to DS:DX -> CF on short read
        push cx
        mov  ah, 3Fh
        mov  bx, [handle]
        int  21h
        pop  cx
        jc   .r
        cmp  ax, cx
        je   .r
        stc
.r:     ret
crcbuf:                               ; EAX = CRC-32 of buf[0..MOD_LEN)
        mov  si, buf
        mov  cx, MOD_LEN
        mov  edx, 0FFFFFFFFh
.b:     lodsb
        xor  dl, al
        mov  bx, 8
.bit:   shr  edx, 1
        jnc  .nx
        xor  edx, 0EDB88320h
.nx:    dec  bx
        jnz  .bit
        loop .b
        mov  eax, edx
        not  eax
        ret
cls:    mov  ax, 0600h                ; clear the screen, cursor home
        mov  bh, 07h
        xor  cx, cx
        mov  dx, 184Fh
        int  10h
        mov  ah, 02h
        xor  bh, bh
        xor  dx, dx
        int  10h
        ret
say:    mov  ah, 09h
        int  21h
        ret
sayfile:
        mov  di, [fnend]
        mov  byte [di], '$'
        mov  dx, fname
        call say
        mov  di, [fnend]
        mov  byte [di], 0
        ret
saynames:                             ; "  anycard, sizecap ..." for [mask]
        xor  bx, bx
        mov  byte [first], 1
.n:     bt   [mask], bx
        jnc  .nx
        cmp  byte [first], 0
        jne  .nf
        mov  dx, m_comma
        call say
.nf:    mov  byte [first], 0
        mov  si, bx
        shl  si, 1
        mov  dx, [names+si]
        call say
.nx:    inc  bx
        cmp  bx, NOPT
        jb   .n
        mov  dx, crlf
        jmp  say

; --- exits ----------------------------------------------------------------
usage:  mov  dx, m_title
        call say
        mov  dx, m_use
        jmp  short out1
e_open: mov  dx, m_open
        jmp  short out1
e_nomod: mov dx, m_nomod
        jmp  short close1
e_len:  mov  dx, m_len
        jmp  short close1
e_read: mov  dx, m_read
        jmp  short close1
e_crc:  mov  dx, m_crc
        jmp  short close1
e_quit: mov  dx, m_quit
        jmp  short close0
e_old:  mov  dx, m_old
        jmp  short close1
e_int:  mov  dx, m_int
        jmp  short close1
e_write: mov dx, m_write
close1: push dx
        mov  ah, 3Eh
        mov  bx, [handle]
        int  21h
        pop  dx
out1:   call say
        mov  ax, 4C01h
        int  21h
close0: push dx
        mov  ah, 3Eh
        mov  bx, [handle]
        int  21h
        pop  dx
out0:   call say
        mov  ax, 4C00h
        int  21h

; --- text (every printed line fits 79 columns) ----------------------------
m_title db 'OBPATCH 1.0 - HP OmniBook 425 ROM card: ATA cards in memory mode'
crlf    db 13, 10, '$'
m_use   db 'Usage: OBPATCH romcard.img   (patches the file in place)', 13, 10
        db 'Keep a copy of the original image. Needs a 386 or later.', 13, 10, '$'
m_stock db 'Stock 425 OBCBIOS found in $'
m_already db 'This image is already patched with:', 13, 10, '  $'
m_redo  db 'To apply a different set, start from your original image.', 13, 10, '$'
OLEN    equ 74
m_o1    db ' 1 [x] anycard       memory mode for every card maker, not only SanDisk', 13, 10, '$'
m_o2    db ' 2 [x] sectors63     cards with 63 sectors/track get their real size   ', 13, 10, '$'
m_o3    db ' 3 [x] sizecap       cards of 4GB and up: size capped at 2GB           ', 13, 10, '$'
m_o4    db ' 4 [x] nopowerdown   no idle power-down (Transcend fix, costs battery) ', 13, 10, '$'
m_o5    db ' 5 [x] nosetfeatures skip SanDisk SET FEATURES (IBM Microdrive fix)    ', 13, 10, '$'
m_keys  db 13, 10, '1-5 toggle, H help, P patch, Q quit: $'
m_help  db '1 anycard: without it, only SanDisk cards get memory mode. Other', 13, 10
        db '  cards run C: in I/O mode (8-bit cards lose odd ports) and are', 13, 10
        db '  "Unrecognised" in the user slots.', 13, 10
        db '2 sectors63: HP tests sectors/track instead of the error bit, so', 13, 10
        db '  cards with 63 sectors/track (most CF cards from 64MB) get size 0.', 13, 10
        db '3 sizecap: HP',39,'s 32-bit card size wraps from 4GB up and HP refuses', 13, 10
        db '  sectors past the wrapped size. DOS uses at most 2GB anyway.', 13, 10
        db '4 nopowerdown: some cards (Transcend) hang after HP wakes them from', 13, 10
        db '  idle power-down. Cards then draw more power while idle.', 13, 10
        db '5 nosetfeatures: the IBM Microdrive aborts everything after these', 13, 10
        db '  SanDisk commands. Their effect on SanDisk cards is not known.', 13, 10
        db 'Recommended: 1-3 always; 4 and 5 if you use those cards.', 13, 10
        db 13, 10, 'Press a key to go back to the menu.$'
m_none  db 13, 10, 'Nothing selected. $'
m_ask1  db 'Patch $'
m_ask2  db ' IN PLACE with:', 13, 10, '  $'
m_ask3  db 'Keep a copy of the original. Y = patch, N = back to the menu', 13, 10, '$'
m_ok    db 'Patched with: $'
m_lingo db 'Write the image to the ROM slot card with LINGO.', 13, 10, '$'
m_quit  db 13, 10, 'Nothing changed.', 13, 10, '$'
m_open  db 'Cannot open the image file.', 13, 10, '$'
m_nomod db 'No OBCBIOS in the ROM card directory: not a 425 ROM card image.', 13, 10, '$'
m_len   db 'Unexpected OBCBIOS length: not a supported 425 build.', 13, 10, '$'
m_read  db 'Read error or image too short.', 13, 10, '$'
m_crc   db 'OBCBIOS is not a known 425 build. Nothing changed.', 13, 10, '$'
m_old   db 'Unexpected bytes at a patch site. Nothing changed.', 13, 10, '$'
m_int   db 'Internal check failed. Nothing changed.', 13, 10, '$'
m_write db 'WRITE FAILED - the image may be damaged, use your copy.', 13, 10, '$'
m_comma db ', $'
n1      db 'anycard$'
n2      db 'sectors63$'
n3      db 'sizecap$'
n4      db 'nopowerdown$'
n5      db 'nosetfeatures$'
names   dw n1, n2, n3, n4, n5
modname db 'OBCBIOS', 0

; Module CRC-32 per combination, index bit n = option n+1. 0 = stock.
crctab  dd 0590D344Eh, 03A6BC7A4h, 0997DA9B2h, 0FA1B5A58h
        dd 0A4B58F0Fh, 0C7D37CE5h, 064C512F3h, 007A3E119h
        dd 0CFE72EA9h, 0AC81DD43h, 00F97B355h, 06CF140BFh
        dd 0325F95E8h, 051396602h, 0F22F0814h, 09149FBFEh
        dd 06D905B1Dh, 00EF6A8F7h, 0ADE0C6E1h, 0CE86350Bh
        dd 09028E05Ch, 0F34E13B6h, 050587DA0h, 0333E8E4Ah
        dd 0FB7A41FAh, 0981CB210h, 03B0ADC06h, 0586C2FECh
        dd 006C2FABBh, 065A40951h, 0C6B26747h, 0A5D494ADh

; patch table: byte option bit, word module offset, byte n, byte has-old,
; [n old bytes], n new bytes. FFh ends.
patches:
        db 0
        dw 2E57h
        db 1, 1, 74h, 0EBh            ; anycard: MANFID 0045 gate
        db 0
        dw 2E61h
        db 1, 1, 74h, 0EBh            ; anycard: card ID xx01 gate
        db 1
        dw 2D58h
        db 1, 1, 01h, 00h             ; sectors63
        db 2
        dw 2D1Fh
        db 49, 0                      ; sizecap A
        db 0FCh,0BEh,00h,04h,26h,0ADh,26h,0ADh,92h,26h,0ADh,26h,0ADh
        db 88h,0C7h,26h,0ADh,26h,0ADh,26h,0ADh,88h,0C3h,0B9h,0F9h,00h
        db 26h,0F3h,0ADh,89h,0D8h,0EBh,10h,80h,0FAh,40h,72h,05h,0B2h
        db 3Fh,83h,0C8h,0FFh,0C3h,90h,90h,90h,90h,90h
        db 2
        dw 2F9Ah
        db 16, 0                      ; sizecap B
        db 0F6h,0E4h,0F7h,0E2h,0E8h,9Fh,0FDh,0Fh,0A4h,0C2h,09h,0C1h
        db 0E0h,09h,90h,90h
        db 3
        dw 2BF4h
        db 1, 1, 04h, 00h             ; nopowerdown
        db 4
        dw 2DBAh
        db 2, 1, 80h, 7Ch, 0EBh, 1Fh  ; nosetfeatures
        db 0FFh

handle  dw 0
dirpos  dd 0
modoff  dd 0
fnend   dw 0
mask    db 1Fh, 0                     ; all on by default (bt needs a word)
first   db 0
ent     times 16 db 0
fname   times 80 db 0
buf:
