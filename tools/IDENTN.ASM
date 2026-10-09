; IDENTN.COM n - READ-ONLY: ATA IDENTIFY DEVICE on a memory-mode ATA card in
; socket n. Borrows mem window 1 (socket 4, ROM drive D:) pointed at socket n
; common memory, writes drive/head A0h + command ECh to the memory-mapped task
; file (+6/+7), waits for DRQ, reads 256 words from the data port (+400h),
; restores window 1 verbatim, saves C:\OBT\IDENT.BIN. Interrupts off while
; borrowed. Needs the card already configured in memory mode (COR index 0).
        cpu 8086
        org 100h
HOSTSEG  equ 0D400h
start:
        mov  al, [82h]
        sub  al, '0'
        cmp  al, 1
        jb   usage
        cmp  al, 3
        ja   usage
        mov  [sock], al
        mov  ah, 88h
        xor  al, al
        mov  bx, 0100h
        int  1Ah
        jc   gwfail
        cmp  bl, 4
        jne  notrom
        mov  [orig_bl], bl
        mov  [orig_cx], cx
        mov  [orig_dx], dx
        mov  [orig_si], si
        cli
        mov  ah, 89h
        xor  al, al
        mov  bh, 1
        mov  bl, [sock]
        mov  cx, 4
        mov  dx, 0C20h
        mov  si, 00D4h
        xor  di, di
        int  1Ah
        jc   maperr
        push ds
        mov  ax, HOSTSEG
        mov  es, ax
        mov  byte [es:0Eh], 02h       ; device control: nIEN
        mov  byte [es:6], 0A0h
        mov  byte [es:7], 0ECh
        mov  cx, 0
        mov  dx, 8
.wait:  mov  al, [es:7]
        test al, 80h
        jnz  .again
        test al, 08h
        jnz  .drq
        test al, 01h
        jnz  .err
.again: loop .wait
        dec  dx
        jnz  .wait
.err:   mov  [stat], al
        pop  ds
        mov  byte [failed], 1
        jmp  short .rest
.drq:   mov  [stat], al
        pop  ds
        mov  di, buf
        mov  cx, 256
.rd:    mov  ax, [es:400h]
        mov  [di], ax
        add  di, 2
        loop .rd
.rest:  call restore
        sti
        jc   resterr
        push cs
        pop  es
        cmp  byte [failed], 0
        jne  idfail
        mov  ah, 3Ch
        xor  cx, cx
        mov  dx, fname
        int  21h
        jc   ferr
        mov  bx, ax
        mov  ah, 40h
        mov  cx, 512
        mov  dx, buf
        int  21h
        mov  ah, 3Eh
        int  21h
        mov  dx, m_ok
        jmp  out0
maperr: call restore
        sti
        mov  dx, m_map
        jmp  out1
idfail: mov  al, [stat]
        call hex8
        mov  dx, m_id
        jmp  out1
usage:  mov  dx, m_use
        jmp  out1
gwfail: mov  dx, m_gw
        jmp  out1
notrom: mov  dx, m_not
        jmp  out1
resterr: mov dx, m_rest
        jmp  out1
ferr:   mov  dx, m_ferr
out1:   mov  ah, 09h
        int  21h
        mov  ax, 4C01h
        int  21h
out0:   mov  ah, 09h
        int  21h
        mov  ax, 4C00h
        int  21h
restore:
        mov  ah, 89h
        xor  al, al
        mov  bh, 1
        mov  bl, [orig_bl]
        mov  cx, [orig_cx]
        mov  dx, [orig_dx]
        mov  dl, 20h
        mov  si, [orig_si]
        xor  di, di
        int  1Ah
        ret
hex8:   push ax
        mov  cl, 4
        shr  al, cl
        call .d
        pop  ax
        and  al, 0Fh
.d:     add  al, '0'
        cmp  al, '9'
        jbe  .o
        add  al, 7
.o:     mov  dl, al
        mov  ah, 02h
        int  21h
        ret
sock    db 0
failed  db 0
stat    db 0
orig_bl db 0
orig_cx dw 0
orig_dx dw 0
orig_si dw 0
fname   db 'C:\OBT\IDENT.BIN', 0
m_ok    db 'IDENTIFY OK', 13, 10, '$'
m_id    db ' = status, IDENTIFY failed (window restored)', 13, 10, '$'
m_use   db 'usage: IDENTN 1|2|3', 13, 10, '$'
m_gw    db 'GetWindow failed', 13, 10, '$'
m_not   db 'window 1 is not socket 4, not touching it', 13, 10, '$'
m_map   db 'SetWindow failed (restored)', 13, 10, '$'
m_rest  db 'RESTORE FAILED - reboot before using D:', 13, 10, '$'
m_ferr  db 'file create failed', 13, 10, '$'
buf:
