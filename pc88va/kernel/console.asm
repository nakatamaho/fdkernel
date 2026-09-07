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
; DOS-C's generic IO dispatcher consumes this table.  The table is PC-88VA
; owned, while DOS semantics (request packets and status bits) remain in the
; common io.asm implementation.
segment _IO_FIXED_DATA
global ConTable
ConTable:       db 0Ah
                dw ConInit
                dw _IOExit
                dw _IOExit
                dw _IOCommandError
                dw ConRead
                dw CommonNdRdExit
                dw CommonNdRdExit
                dw ConInpFlush
                dw ConWrite
                dw ConWrite
                dw _IOExit

segment _TEXT class=CODE public use16
extern _IOExit, _IODone, _IOErrorExit, _IOCommandError, _ReqPktPtr
extern pc88va_console_getc_
extern pc88va_m11_character_

; Bridge the common device-driver call (DS = DOS data) to the M11 ABI (DS = CS).
global pc88va_dos_getc_
pc88va_dos_getc_:
                push ds
                push cs
                pop ds
                mov ax, pc88va_m11_character_
                call pc88va_console_getc_
                pop ds
                ret

global ConInit, ConRead, ConInpFlush, ConWrite, CommonNdRdExit
ConInit:
                jmp _IOExit

ConRead:
                jcxz ConReadDone
ConReadLoop:
                call pc88va_dos_getc_
                cmp ax, 1
                je ConReadLoop
                or ax, ax
                jz ConReadReady
                jmp _IOErrorExit
ConReadReady:
                mov al, [cs:pc88va_m11_character_]
                stosb
                loop ConReadLoop
ConReadDone:
                jmp _IOExit

; Non-destructive status is a single M11 poll.  The common dispatcher owns the
; request packet and maps busy/done/error status for DOS callers.
CommonNdRdExit:
                call pc88va_dos_getc_
                cmp ax, 1
                jne CommonNdCheck
                jmp _IODone
CommonNdCheck:
                or ax, ax
                jz CommonNdReady
                jmp _IOErrorExit
CommonNdReady:
                lds bx, [cs:_ReqPktPtr]
                cmp byte [bx+2], 6
                je _IOExit
                mov al, [cs:pc88va_m11_character_]
                mov [bx+0Dh], al
                jmp _IOExit

ConInpFlush:
                jmp _IOExit

ConWrite:
                or cx, cx
                jnz ConWriteLoop
                jmp _IOExit
ConWriteLoop:
                xor ax, ax
                mov al, [es:di]
                inc di
                call pc88va_console_putc_
                or ax, ax
                jz ConWriteReady
                jmp _IOErrorExit
ConWriteReady:
                loop ConWriteLoop
                jmp _IOExit
%else
segment _TEXT class=CODE public use16
%endif
global pc88va_console_putc_
global pc88va_console_diagnostic_
global _pc88va_m09_message
global _pc88va_m09_diagnostic_complete
global _pc88va_console_preconditions_valid
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
        ; Establish the diagnostic precondition before its first putc call.
        ; Each standalone putc still validates its own inherited vector.
        push bx
        push es
        xor bx, bx
        mov es, bx
        mov bx, [es:083h * 4]
        or bx, [es:083h * 4 + 2]
        pop es
        pop bx
        jnz _pc88va_console_preconditions_valid
        mov ax, 0ffffh
        jmp _pc88va_m09_diagnostic_complete
_pc88va_console_preconditions_valid:
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
