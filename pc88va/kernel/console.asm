; SPDX-License-Identifier: GPL-2.0-or-later
; One-byte adapter to the independently public PC-88VA Text BIOS service.
bits 16
%ifdef NEC98
%error PC88VA and NEC98 selectors are mutually exclusive
%endif
%ifdef IBMPC
%error PC88VA and IBMPC selectors are mutually exclusive
%endif
%ifndef PC88VA
%error PC88VA selector is required
%endif

%ifndef CONSOLE_FLAT_TEST
segment _TEXT class=CODE public use16
%endif
global pc88va_console_putc_
global pc88va_console_diagnostic_
global _pc88va_m09_message
global _pc88va_m09_diagnostic_complete
global pc88va_console_putc_.ready
global pc88va_console_putc_.firmware

; Open Watcom small-model register convention: AX = unsigned character.
; AX = 0 on firmware return, FFFFh for unsupported byte or missing vector.
; Other general registers, DS, ES, FLAGS and the caller's stack are preserved.
pc88va_console_putc_:
        pushf
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        cmp ax, 13
        je .accepted
        cmp ax, 10
        je .accepted
        cmp ax, 020h
        jb .unavailable
        cmp ax, 07eh
        ja .unavailable
.accepted:
        xor bx, bx
        mov es, bx
        mov bx, [es:083h * 4]
        or bx, [es:083h * 4 + 2]
        jz .unavailable
.ready:
        ; The word is the byte followed by a NUL; no global scratch buffer.
        push ax
        push ss
        pop ds
        mov si, sp
        mov dx, 08000h
        mov ah, 02h
.firmware:
        int 083h
        add sp, 2
        xor ax, ax
        jmp short .restore
.unavailable:
        mov ax, 0ffffh
.restore:
        pop es
        pop ds
        pop bp
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        popf
        ret

pc88va_console_diagnostic_:
        pushf
        push si
        mov si, _pc88va_m09_message
.next:
        xor ax, ax
        mov al, [cs:si]
        inc si
        test al, al
        jz _pc88va_m09_diagnostic_complete
        call pc88va_console_putc_
        test ax, ax
        jz .next
_pc88va_m09_diagnostic_complete:
        pop si
        popf
        ret

_pc88va_m09_message:
        db 13, 'FreeDOS/PC-88VA M09', 13, 10
        db '012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789'
        db 13, 10, 'CONSOLE OK', 13, 10, 0
        db 'M09SERVICE:CONSOLE_PUTC:TEXT_BIOS', 0
