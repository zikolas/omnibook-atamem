; MEMDUMP.COM seg len - write seg:0000 for len bytes (hex, len 0 = 64K)
; to C:\OBT\MEM.BIN.  Read-only on memory.
        org 100h
start:
        mov     si, 81h
        call    gethex
        mov     [seg_], ax
        call    gethex
        mov     [len_], ax
        mov     ah, 3Ch
        xor     cx, cx
        mov     dx, fname
        int     21h
        jc      fail
        mov     bx, ax
        mov     cx, [len_]
        or      cx, cx
        jnz     .one
        mov     cx, 8000h
        push    ds
        mov     ds, [seg_]
        xor     dx, dx
        mov     ah, 40h
        int     21h
        mov     dx, 8000h
        mov     cx, 8000h
        mov     ah, 40h
        int     21h
        pop     ds
        jc      fail
        jmp     short .close
.one:
        push    ds
        mov     ds, [seg_]
        xor     dx, dx
        mov     ah, 40h
        int     21h
        pop     ds
        jc      fail
.close:
        mov     ah, 3Eh
        int     21h
        mov     dx, m_ok
        mov     ah, 09h
        int     21h
        mov     ax, 4C00h
        int     21h
fail:
        mov     dx, m_bad
        mov     ah, 09h
        int     21h
        mov     ax, 4C01h
        int     21h

gethex:                         ; DS:SI -> AX, skips leading blanks
        xor     ax, ax
.sk:    mov     bl, [si]
        cmp     bl, ' '
        jne     .dig
        inc     si
        jmp     .sk
.dig:   mov     bl, [si]
        sub     bl, '0'
        jb      .end
        cmp     bl, 9
        jbe     .add
        and     bl, 0DFh
        sub     bl, 7
        cmp     bl, 10
        jb      .end
        cmp     bl, 15
        ja      .end
.add:   shl     ax, 4
        or      al, bl
        inc     si
        jmp     .dig
.end:   ret

seg_    dw 0
len_    dw 0
fname   db 'C:\OBT\MEM.BIN', 0
m_ok    db 'OK', 13, 10, '$'
m_bad   db 'FAIL', 13, 10, '$'
