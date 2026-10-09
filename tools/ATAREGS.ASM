; ATAREGS.COM n - READ-ONLY: print the memory-mapped ATA task file (offsets
; 1-7 and alt status at 0Eh) of a memory-mode ATA card in socket n, through
; mem window 1 borrowed from the ROM drive and restored. Issues no command.
        cpu 8086
        org 100h
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
        jc   bad
        cmp  bl, 4
        jne  bad
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
        jc   rest
        mov  ax, 0D400h
        mov  es, ax
        mov  di, regs
        mov  bx, 1
.rd:    mov  al, [es:bx]
        mov  [di], al
        inc  di
        inc  bx
        cmp  bx, 8
        jb   .rd
        mov  al, [es:0Eh]
        mov  [di], al
rest:   mov  ah, 89h
        xor  al, al
        mov  bh, 1
        mov  bl, [orig_bl]
        mov  cx, [orig_cx]
        mov  dx, [orig_dx]
        mov  dl, 20h
        mov  si, [orig_si]
        xor  di, di
        int  1Ah
        sti
        mov  si, names
        mov  di, regs
        mov  cx, 8
.pr:    push cx
        mov  dx, si
        mov  ah, 09h
        int  21h
        add  si, 6
        mov  al, [di]
        inc  di
        call hex8
        pop  cx
        loop .pr
        mov  dx, crlf
        mov  ah, 09h
        int  21h
        mov  ax, 4C00h
        int  21h
usage:
bad:    mov  dx, m_bad
        mov  ah, 09h
        int  21h
        mov  ax, 4C01h
        int  21h
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
orig_bl db 0
orig_cx dw 0
orig_dx dw 0
orig_si dw 0
regs    times 8 db 0
names   db ' ERR=$'
        db ' CNT=$'
        db ' SEC=$'
        db ' CYL=$'
        db ' CYH=$'
        db ' DRV=$'
        db ' STA=$'
        db ' ALT=$'
crlf    db 13, 10, '$'
m_bad   db 'usage: ATAREGS 1|2|3 (window 1 must be socket 4)', 13, 10, '$'
