; ATAPWR.COM n cc - issue ATA power command cc (hex, only E0-E5: standby/idle
; immediate, standby/idle, check power mode) to the memory-mode ATA card in
; socket n, wait up to ~30 s for BSY to clear, print STA ERR CNT. No data
; transfer. Window 1 borrowed from the ROM drive and restored.
        cpu 386
        org 100h
start:
        mov  al, [82h]
        sub  al, '0'
        cmp  al, 1
        jb   bad
        cmp  al, 3
        ja   bad
        mov  [sock], al
        mov  si, 83h
.sk:    cmp  byte [si], ' '
        jne  .h
        inc  si
        jmp  .sk
.h:     call hex2
        jc   bad
        cmp  al, 0E0h
        jb   bad
        cmp  al, 0E5h
        ja   bad
        mov  [cmd], al
        mov  ah, 88h
        xor  al, al
        mov  bx, 0100h
        int  1Ah
        jc   bad
        cmp  bl, 4
        jne  bad
        mov  [ocx], cx
        mov  [odx], dx
        mov  [osi], si
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
        mov  byte [es:2], 0
        mov  byte [es:6], 0E0h
        mov  al, [cmd]
        mov  [es:7], al
        mov  ecx, 30000000h
.w:     test byte [es:7], 80h
        jz   .d
        dec  ecx
        jnz  .w
.d:     mov  al, [es:7]
        mov  [v], al
        mov  al, [es:1]
        mov  [v+1], al
        mov  al, [es:2]
        mov  [v+2], al
rest:   mov  ah, 89h
        xor  al, al
        mov  bx, 0104h
        mov  cx, [ocx]
        mov  dx, [odx]
        mov  dl, 20h
        mov  si, [osi]
        xor  di, di
        int  1Ah
        mov  dx, m_r
        mov  ah, 09h
        int  21h
        mov  si, v
        mov  cx, 3
.p:     lodsb
        push cx
        push si
        call hex8
        mov  dl, ' '
        mov  ah, 2
        int  21h
        pop  si
        pop  cx
        loop .p
        mov  dx, crlf
        mov  ah, 09h
        int  21h
        int  20h
bad:    mov  dx, m_bad
        mov  ah, 09h
        int  21h
        int  20h
hex2:   xor  ax, ax
        mov  cx, 2
.l:     mov  bl, [si]
        sub  bl, '0'
        jb   .e
        cmp  bl, 9
        jbe  .a
        and  bl, 0DFh
        sub  bl, 7
        cmp  bl, 10
        jb   .e
        cmp  bl, 15
        ja   .e
.a:     shl  al, 4
        or   al, bl
        inc  si
        loop .l
        clc
        ret
.e:     stc
        ret
hex8:   push ax
        mov  cl, 4
        shr  al, cl
        call .d
        pop  ax
        and  al, 0Fh
.d:     add  al, '0'
        cmp  al, '9'
        jbe  .q
        add  al, 7
.q:     mov  dl, al
        mov  ah, 02h
        int  21h
        ret
sock db 0
cmd  db 0
ocx  dw 0
odx  dw 0
osi  dw 0
v    db 0, 0, 0
m_r  db 'STA ERR CNT: $'
m_bad db 'usage: ATAPWR 1|2|3 E0..E5', 13, 10, '$'
crlf db 13, 10, '$'
