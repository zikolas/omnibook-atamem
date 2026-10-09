; OBCBIOS size-cap patch (module offsets). Patch A replaces 2D1F-2D4F,
; Patch B replaces 2F9A-2FA9. Assembled separately at their own origins.
        cpu 386
        section a start=0 vstart=2D1Fh
pa:     cld
        mov  si, 0400h
        es lodsw                      ; w0
        es lodsw                      ; w1 cylinders
        xchg dx, ax
        es lodsw                      ; w2
        es lodsw                      ; w3 heads
        mov  bh, al
        es lodsw                      ; w4
        es lodsw                      ; w5
        es lodsw                      ; w6 sectors
        mov  bl, al
        mov  cx, 00F9h
        rep es lodsw                  ; w7-w255
        mov  ax, bx
        jmp  short 2D50h
clamp:  cmp  dl, 40h                  ; DX:AX = sectors (DH = 0)
        jb   .r
        mov  dl, 3Fh
        or   ax, -1
.r:     ret
        times (2D50h-($-$$)-2D1Fh) nop
        section b start=100h vstart=2F9Ah
pb:     mul  ah
        mul  dx
        call clamp
        shld dx, ax, 9
        shl  ax, 9
        times (2FAAh-($-$$)-2F9Ah) nop
