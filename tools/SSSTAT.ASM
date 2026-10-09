; SSSTAT.COM - read-only: Socket Services GetStatus (AX=8F00) for sockets 1-4,
; prints DX per socket (DL bit7 present, bit6 ready, bit0 WP).
        cpu 8086
        org 100h
        mov  bl, 1
.s:     push bx
        mov  al, bl
        add  al, '0'
        mov  [m_s+1], al
        mov  dx, m_s
        mov  ah, 09h
        int  21h
        pop  bx
        push bx
        mov  ax, 8F00h
        xor  bh, bh
        int  1Ah
        mov  ax, dx
        call hex16
        pop  bx
        inc  bl
        cmp  bl, 5
        jb   .s
        mov  dx, crlf
        mov  ah, 09h
        int  21h
        int  20h
hex16:  push ax
        mov  al, ah
        call hex8
        pop  ax
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
m_s     db ' sN DX=$'
crlf    db 13, 10, '$'
