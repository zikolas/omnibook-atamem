; POLLATA.COM n - READ-ONLY: once a second for 40 s, sample the ATA status and
; alt status of a memory-mode ATA card in socket n (mem window 1 borrowed from
; the ROM drive, restored after each sample) plus VLSI EC/ED regs 38h/39h.
; Prints one line per sample: tick-offset STA ALT r38 r39.
        cpu 8086
        org 100h
start:
        mov  al, [82h]
        sub  al, '0'
        cmp  al, 1
        jb   bad
        cmp  al, 3
        ja   bad
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
        call ticks
        mov  [t0], dx
        mov  byte [n], 40
.loop:
        call sample
        call ticks
        sub  dx, [t0]
        mov  ax, dx
        call hex16
        mov  dx, s_sta
        call say
        mov  al, [v_sta]
        call hex8
        mov  dx, s_alt
        call say
        mov  al, [v_alt]
        call hex8
        mov  dx, s_38
        call say
        mov  al, [v_38]
        call hex8
        mov  dx, s_39
        call say
        mov  al, [v_39]
        call hex8
        mov  dx, crlf
        call say
        call ticks
        mov  [tw], dx
.wt:    call ticks
        sub  dx, [tw]
        cmp  dx, 18
        jb   .wt
        dec  byte [n]
        jnz  .loop
        mov  ax, 4C00h
        int  21h
bad:    mov  dx, m_bad
        call say
        mov  ax, 4C01h
        int  21h

sample:
        pushf
        cli
        mov  al, 38h
        out  0ECh, al
        jmp  short $+2
        in   al, 0EDh
        mov  [v_38], al
        mov  al, 39h
        out  0ECh, al
        jmp  short $+2
        in   al, 0EDh
        mov  [v_39], al
        mov  ah, 89h
        xor  al, al
        mov  bh, 1
        mov  bl, [sock]
        mov  cx, 4
        mov  dx, 0C20h
        mov  si, 00D4h
        xor  di, di
        int  1Ah
        jc   .rest
        push es
        mov  ax, 0D400h
        mov  es, ax
        mov  al, [es:7]
        mov  [v_sta], al
        mov  al, [es:0Eh]
        mov  [v_alt], al
        pop  es
.rest:  mov  ah, 89h
        xor  al, al
        mov  bh, 1
        mov  bl, [orig_bl]
        mov  cx, [orig_cx]
        mov  dx, [orig_dx]
        mov  dl, 20h
        mov  si, [orig_si]
        xor  di, di
        int  1Ah
        popf
        ret

ticks:  push ax
        push cx
        xor  ah, ah
        int  1Ah
        pop  cx
        pop  ax
        ret
say:    mov  ah, 09h
        int  21h
        ret
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
sock    db 0
n       db 0
t0      dw 0
tw      dw 0
orig_bl db 0
orig_cx dw 0
orig_dx dw 0
orig_si dw 0
v_sta   db 0
v_alt   db 0
v_38    db 0
v_39    db 0
s_sta   db ' STA=$'
s_alt   db ' ALT=$'
s_38    db ' 38=$'
s_39    db ' 39=$'
crlf    db 13, 10, '$'
m_bad   db 'usage: POLLATA 1|2|3 (window 1 must be socket 4)', 13, 10, '$'
