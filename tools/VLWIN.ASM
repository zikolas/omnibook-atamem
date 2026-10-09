; VLWIN.COM - read-only dump of the VLSI PCMCIA controller registers of an
; HP OmniBook 425 through the EC/ED index/data pair (CLI around each pair).
;   1Eh-25h  I/O windows 4-7: reg = (size-1)<<4 | socket select (bits 2-3) |
;            base bits 9-8, reg+1 = base low byte
;   34h-39h  socket 3, 2, 1 control: in I/O mode bit 0 = 16-bit data path.
; Example: an ATA C: card in I/O mode shows 1E=75 1F=F0 (1F0h) 20=07 21=F6
; (3F6h) 34=79; in memory mode the windows are unused and 34=D8.
        org 100h
start:
        mov  si, regs
.next:
        lodsb
        cmp  al, 0FFh
        je   .done
        mov  bl, al                   ; BL = index
        call prhex2                   ; print index
        mov  al, '='
        call prchar
        pushf
        cli
        mov  al, bl
        out  0ECh, al
        jmp  short $+2                ; settle
        in   al, 0EDh
        popf
        call prhex2
        mov  al, ' '
        call prchar
        jmp  .next
.done:
        call crlf
        int  20h

prhex2:                               ; AL -> two hex digits
        push ax
        shr  al, 4
        call .nib
        pop  ax
        and  al, 0Fh
.nib:
        add  al, '0'
        cmp  al, '9'
        jbe  .pr
        add  al, 7
.pr:
        push bx
        mov  ah, 0Eh
        xor  bx, bx
        int  10h
        pop  bx
        ret
prchar:
        push bx
        mov  ah, 0Eh
        xor  bx, bx
        int  10h
        pop  bx
        ret
crlf:
        mov  al, 13
        call prchar
        mov  al, 10
        call prchar
        ret

regs:   db 1Eh, 1Fh, 20h, 21h, 22h, 23h, 24h, 25h   ; I/O windows 4-7
        db 34h, 35h, 36h, 37h, 38h, 39h              ; socket 3, 2, 1 pairs
        db 0FFh
