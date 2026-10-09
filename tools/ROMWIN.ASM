; ROMWIN.COM xxxx - READ-ONLY: point mem window 1 (socket 4, the ROM card,
; normally D: at D400) at ROM-card offset xxxx*4K, copy the 16K it shows to
; C:\OBT\ROMWIN.BIN, restore the window. Interrupts off while borrowed.
        cpu 8086
        org 100h

WINNUM   equ 1
HOSTSEG  equ 0D400h

start:
        mov  si, 81h
        call gethex
        mov  [cardoff], ax
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
        cmp  bl, 4
        je   .ok4
        mov  dx, m_notrom
        jmp  say_exit
.ok4:
        cli
        mov  ah, 89h
        xor  al, al
        mov  bh, WINNUM
        mov  bl, 4
        mov  cx, [orig_cx]
        mov  dx, [orig_dx]
        mov  si, [orig_si]
        mov  di, [cardoff]
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
        mov  cx, 2000h
        cld
        rep  movsw
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
        mov  cx, 4000h
        mov  dx, buf
        int  21h
        mov  ah, 3Eh
        int  21h
        mov  dx, m_ok
        jmp  say_exit0
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
        mov  ah, 09h
        int  21h
        mov  ax, 4C01h
        int  21h
say_exit0:
        mov  ah, 09h
        int  21h
        mov  ax, 4C00h
        int  21h

restore:
        mov  ah, 89h
        xor  al, al
        mov  bh, WINNUM
        mov  bl, [orig_bl]
        mov  cx, [orig_cx]
        mov  dx, [orig_dx]
        mov  si, [orig_si]
        xor  di, di
        int  1Ah
        ret

gethex:
        xor  ax, ax
.sk:    mov  bl, [si]
        cmp  bl, ' '
        jne  .dig
        inc  si
        jmp  .sk
.dig:   mov  bl, [si]
        sub  bl, '0'
        jb   .end
        cmp  bl, 9
        jbe  .add
        and  bl, 0DFh
        sub  bl, 7
        cmp  bl, 10
        jb   .end
        cmp  bl, 15
        ja   .end
.add:   mov  cl, 4
        shl  ax, cl
        or   al, bl
        inc  si
        jmp  .dig
.end:   ret

cardoff  dw 0
orig_bl  db 0
orig_cx  dw 0
orig_dx  dw 0
orig_si  dw 0
fname    db 'C:\OBT\ROMWIN.BIN', 0
m_ok     db 'ROMWIN OK', 13, 10, '$'
m_gwfail db 'GetWindow failed', 13, 10, '$'
m_notrom db 'window 1 is not socket 4, not touching it', 13, 10, '$'
m_mapfail db 'SetWindow failed (restored)', 13, 10, '$'
m_restfail db 'RESTORE FAILED - reboot before using D:', 13, 10, '$'
m_ferr   db 'file create failed', 13, 10, '$'
buf:
