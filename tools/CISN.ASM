; CISN.COM n - READ-ONLY: dump socket n's (1-3) attribute memory (first 1K of
; attr space = 512 CIS bytes at even addresses) to C:\OBT\CISn.BIN.
; Mem window 1 (socket 4, the write-protected ROM drive D:) is pointed at
; socket n attr space (DH=0Eh), copied with interrupts off, restored.
; No card writes, no DOS calls while borrowed.
        cpu 8086
        org 100h

WINNUM   equ 1
HOSTSEG  equ 0D400h
HOSTPARA equ 000D4h


start:
        mov  al, [82h]               ; socket digit
        sub  al, '0'
        cmp  al, 1
        jb   .bad
        cmp  al, 3
        jbe  .sok
.bad:   mov  dx, m_usage
        jmp  say_exit
.sok:   mov  [sock], al
        add  al, '0'
        mov  [fname+10], al
        mov  ah, 88h
        xor  al, al
        mov  bh, WINNUM
        xor  bl, bl
        int  1Ah
        jnc  .gw
        mov  dx, m_gwfail
        jmp  say_exit
.gw:
        mov  [orig_bl], bl
        mov  [orig_cx], cx
        mov  [orig_dx], dx
        mov  [orig_si], si
        mov  [orig_di], di
        cmp  bl, 4                    ; expect the ROM drive on window 1
        je   .ok4
        mov  dx, m_notrom
        jmp  say_exit
.ok4:
        cli
        mov  ah, 89h
        xor  al, al
        mov  bh, WINNUM
        mov  bl, [sock]
        mov  cx, 4
        mov  dh, 0Eh
        mov  dl, 20h
        mov  si, HOSTPARA
        xor  di, di
        int  1Ah
        jc   maperr
        push ds
        push es
        push cs
        pop  es
        mov  ax, HOSTSEG
        mov  ds, ax
        xor  si, si
        mov  di, buf
        mov  cx, 1024
        cld
        rep  movsb
        pop  es
        pop  ds
        call restore
        sti
        jc   resterr
        mov  ah, 3Ch
        xor  cx, cx
        mov  dx, fname
        int  21h
        jc   ferr
        mov  bx, ax
        mov  ah, 40h
        mov  cx, 1024
        mov  dx, buf
        int  21h
        mov  ah, 3Eh
        int  21h
        mov  dx, m_ok
        call say
        mov  ax, [orig_di]
        call hex16
        mov  dx, m_crlf
        call say
        mov  ax, 4C00h
        int  21h
maperr:
        call restore
        sti
        mov  dx, m_mapfail
        jmp  say_exit
resterr:
        mov  dx, m_restfail
        jmp  say_exit
ferr:
        mov  dx, m_ferr
say_exit:
        call say
        mov  ax, 4C01h
        int  21h

restore:
        mov  ah, 89h
        xor  al, al
        mov  bh, WINNUM
        mov  bl, [orig_bl]
        mov  cx, [orig_cx]
        mov  dx, [orig_dx]
        mov  dl, 20h
        mov  si, [orig_si]
        xor  di, di
        int  1Ah
        ret

say:
        mov  ah, 09h
        int  21h
        ret
hex16:
        push ax
        mov  al, ah
        call hex8
        pop  ax
hex8:
        push ax
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

orig_bl  db 0
sock     db 0
m_usage  db 'usage: CISN 1|2|3', 13, 10, '$'
orig_cx  dw 0
orig_dx  dw 0
orig_si  dw 0
orig_di  dw 0
fname    db 'C:\OBT\CISn.BIN', 0
m_ok     db 'CISN OK, win1 DI was $'
m_crlf   db 13, 10, '$'
m_gwfail db 'GetWindow failed', 13, 10, '$'
m_notrom db 'window 1 is not socket 4, not touching it', 13, 10, '$'
m_mapfail db 'SetWindow failed (restored)', 13, 10, '$'
m_restfail db 'RESTORE FAILED - reboot before using D:', 13, 10, '$'
m_ferr   db 'file create failed', 13, 10, '$'
buf:
