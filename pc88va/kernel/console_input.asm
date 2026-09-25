; SPDX-License-Identifier: GPL-2.0-or-later
; M11: read-only matrix polling; no firmware calls, queue or driver echo.
; Matrix coordinates: pinned VAEG io/serial.c scantomap/updatekeymap.
; ASCII/Shift mapping: pinned VAEG sdl2/kbdpaste.c map_ascii.
bits 16
cpu 8086
%ifndef PC88VA
%error PC88VA selector is required
%endif
%ifdef NEC98
%error Mixed machine selectors
%endif
%ifdef IBMPC
%error Mixed machine selectors
%endif

%ifndef M11_FLAT_TEST
%ifdef PC88VA_M13
%include "kernel/m13_segments.inc"
segment M13_PLATFORM_TEXT
%else
segment _TEXT class=CODE public use16
%endif
extern pc88va_m10_state_
extern pc88va_console_putc_
%endif
global pc88va_console_getc_, pc88va_console_getc_dos_
global pc88va_console_peek_dos_, pc88va_console_read_dos_
global pc88va_m11_character_
global pc88va_m11_poll_matrix, pc88va_m11_return
global pc88va_m11_storage_begin, pc88va_m11_storage_end
global m11_pending_valid

; AX=&exported word, DS=CS, M10 ready, IF=DF=TF=0 for the public raw entry.
; AX: 0 character, 1 no new input, 2 unsupported/ambiguous new input,
; ffff invalid precondition. Only status zero writes the character word.
; No queue: multiple non-modifier make edges in one poll are rejected.
; First poll adopts held keys; a subsequent release and make is required.
pc88va_console_getc_:
        pushf
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov bp, sp
        test word [ss:bp+16], 0700h
        jnz m11_bad
        xor bp, bp
        jmp short m11_validate_common

; The common DOS device dispatcher deliberately inherits IF=1 after INT 21h.
; Keep the public raw entry strict, but expose an integration entry which
; accepts that inherited IF while retaining the same non-reentrant poll and
; preserving the caller's architectural flags.  No interrupt is installed or
; suppressed here; this is only the established caller-contract boundary.
pc88va_console_getc_dos_:
        pushf
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov bp, sp
        test word [ss:bp+16], 0500h
        jnz m11_bad
        mov bp, 1
m11_validate_common:
        cmp ax, pc88va_m11_character_
        jne m11_bad
        mov bx, ds
        mov dx, cs
        cmp bx, dx
        jne m11_bad
        cmp byte [cs:pc88va_m10_state_], 2
        jne m11_bad
pc88va_m11_poll_matrix:
        xor dx, dx
        xor si, si
        mov cx, 15
m11_read:
        in al, dx
        mov [cs:m11_current+si], al
        inc dx
        inc si
        loop m11_read
        cmp byte [cs:m11_adopted], 0
        jne m11_edges
        xor si, si
        mov cx, 15
m11_adopt:
        mov al, [cs:m11_current+si]
        mov [cs:m11_previous+si], al
        inc si
        loop m11_adopt
        mov byte [cs:m11_adopted], 1
        jmp m11_empty
m11_edges:
        xor si, si
        xor di, di
        mov bx, 0ffffh
m11_row:
        mov al, [cs:m11_previous+si]
        mov ah, [cs:m11_current+si]
        mov [cs:m11_previous+si], ah
        not ah
        and al, ah
        ; Ignore derived Return and Shift/INSDEL aliases and physical Shift.
        cmp si, 1
        jne m11_not_return_alias
        and al, 7fh
m11_not_return_alias:
        cmp si, 8
        jne m11_not_shift_alias
        and al, 0b7h
        ; DOS interprets Ctrl with a letter; a modifier edge is not a key.
        or bp, bp
        jz m11_not_shift_alias
        and al, 7fh
m11_not_shift_alias:
        cmp si, 14
        jne m11_not_shift
        and al, 0f3h
m11_not_shift:
        mov dx, si
        shl dx, 1
        shl dx, 1
        shl dx, 1
        mov cx, 8
m11_bit:
        test al, 1
        jz m11_next_bit
        cmp bx, 0ffffh
        jne m11_multiple
        mov bx, dx
        jmp short m11_next_bit
m11_multiple:
        mov di, 1
m11_next_bit:
        shr al, 1
        inc dx
        loop m11_bit
        inc si
        cmp si, 15
        jb m11_row
        or di, di
        jnz m11_unsupported
        cmp bx, 0ffffh
        je m11_empty
        ; Unsupported modifier/mode combinations cannot become plain ASCII.
        mov al, [cs:m11_current+8]
        not al
        or bp, bp
        jz m11_check_modes
        and al, 7fh
m11_check_modes:
        test al, 0b0h
        jnz m11_unsupported
        test byte [cs:m11_current+10], 80h
        jz m11_unsupported
        mov al, [cs:m11_current+13]
        not al
        test al, 0fh
        jnz m11_unsupported
        ; The early raw ABI still rejects Escape and Tab. DOS needs their
        ; ASCII control values; break/EOF policy stays in the common kernel.
        or bp, bp
        jz m11_find_key
        cmp bl, 9*8+7
        mov al, 27
        je m11_store_character
        cmp bl, 10*8+0
        mov al, 9
        je m11_store_character
m11_find_key:
        mov si, m11_keys
        mov cx, (m11_keys_end-m11_keys)/3
m11_lookup:
        cmp bl, [cs:si]
        je m11_found
        add si, 3
        loop m11_lookup
        jmp short m11_unsupported
m11_found:
        test byte [cs:m11_current+8], 80h
        jnz m11_apply_shift
        mov al, [cs:si+1]
        sub al, 'a'
        cmp al, 25
        ja m11_unsupported
        inc al
        jmp short m11_store_character
m11_apply_shift:
        mov al, [cs:m11_current+14]
        not al
        and al, 0ch
        jz m11_plain
        inc si
m11_plain:
        mov al, [cs:si+1]
        or al, al
        jz m11_unsupported
m11_store_character:
        xor ah, ah
        mov [cs:pc88va_m11_character_], ax
        xor ax, ax
        jmp short pc88va_m11_return
m11_empty:
        mov ax, 1
        jmp short pc88va_m11_return
m11_unsupported:
        mov ax, 2
        jmp short pc88va_m11_return
m11_bad:
        mov ax, 0ffffh
pc88va_m11_return:
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

; DOS input-status callers must not consume a character merely by observing
; it.  Keep one ready character latched until the corresponding C_INPUT read
; consumes it.  The latch is deliberately one character deep: the existing
; matrix contract rejects ambiguous simultaneous make edges, and a caller
; must consume a reported character before another one is admitted.
pc88va_console_peek_dos_:
        cmp byte [cs:m11_pending_valid], 0
        jne m11_peek_ready
        call pc88va_console_getc_dos_
        or ax, ax
        jne m11_peek_return
        mov byte [cs:m11_pending_valid], 1
m11_peek_ready:
        xor ax, ax
m11_peek_return:
        ret

; C_INPUT is the consuming side of the same contract.  A character found by
; an earlier non-destructive status request is returned without requiring a
; new matrix edge; otherwise perform one ordinary poll.
pc88va_console_read_dos_:
        cmp byte [cs:m11_pending_valid], 0
        je m11_read_poll
        mov byte [cs:m11_pending_valid], 0
        xor ax, ax
        ret
m11_read_poll:
        call pc88va_console_getc_dos_
        ret

pc88va_m11_storage_begin:
pc88va_m11_character_: dw 0
m11_pending_valid: db 0
m11_adopted: db 0
m11_previous: times 15 db 0
m11_current: times 15 db 0
pc88va_m11_storage_end:

; One row/bit coordinate, unshifted byte, shifted byte per physical key.
; Unsupported Shift+0 maps to zero internally, never to a returned NUL.
m11_keys:
        db 6*8+1, '1', '!'
        db 6*8+2, '2', '"'
        db 6*8+3, '3', '#'
        db 6*8+4, '4', '$'
        db 6*8+5, '5', '%'
        db 6*8+6, '6', '&'
        db 6*8+7, '7', 39
        db 7*8+0, '8', '('
        db 7*8+1, '9', ')'
        db 6*8+0, '0', 0
        db 5*8+7, '-', '='
        db 5*8+6, '^', 96
        db 5*8+4, 92, '|'
        db 4*8+1, 'q', 'Q'
        db 4*8+7, 'w', 'W'
        db 2*8+5, 'e', 'E'
        db 4*8+2, 'r', 'R'
        db 4*8+4, 't', 'T'
        db 5*8+1, 'y', 'Y'
        db 4*8+5, 'u', 'U'
        db 3*8+1, 'i', 'I'
        db 3*8+7, 'o', 'O'
        db 4*8+0, 'p', 'P'
        db 2*8+0, '@', '~'
        db 5*8+3, '[', '{'
        db 2*8+1, 'a', 'A'
        db 4*8+3, 's', 'S'
        db 2*8+4, 'd', 'D'
        db 2*8+6, 'f', 'F'
        db 2*8+7, 'g', 'G'
        db 3*8+0, 'h', 'H'
        db 3*8+2, 'j', 'J'
        db 3*8+3, 'k', 'K'
        db 3*8+4, 'l', 'L'
        db 7*8+3, ';', '+'
        db 7*8+2, ':', '*'
        db 5*8+5, ']', '}'
        db 5*8+2, 'z', 'Z'
        db 5*8+0, 'x', 'X'
        db 2*8+3, 'c', 'C'
        db 4*8+6, 'v', 'V'
        db 2*8+2, 'b', 'B'
        db 3*8+6, 'n', 'N'
        db 3*8+5, 'm', 'M'
        db 7*8+4, ',', '<'
        db 7*8+5, '.', '>'
        db 7*8+6, '/', '?'
        db 7*8+7, 92, '_'
        db 9*8+6, ' ', ' '
        db 12*8+5, 8, 8
        db 14*8+0, 13, 13
        db 14*8+1, 13, 13
m11_keys_end:

%ifndef M11_FLAT_TEST
global pc88va_m11_diagnostic_, pc88va_m11_control_, pc88va_m11_count_
global pc88va_m11_empty_count_, pc88va_m11_history_
global pc88va_m11_k1, pc88va_m11_k4, pc88va_m11_k5, pc88va_m11_k8, pc88va_m11_k9
; Qualification caller owns echo. It stops on a count, never on a fixed text.
pc88va_m11_diagnostic_:
pc88va_m11_k1:
        mov cx, 8
        cmp byte [cs:pc88va_m11_control_], 0
        je m11_next
        cmp byte [cs:pc88va_m11_control_], 1
        jne m11_diagnostic_bad
        mov cx, 1
m11_next:
        mov ax, pc88va_m11_character_
pc88va_m11_k4:
        call pc88va_console_getc_
pc88va_m11_k5:
        cmp ax, 1
        je m11_no_input
        or ax, ax
        jnz m11_diagnostic_bad
        mov bx, [cs:pc88va_m11_count_]
        cmp bx, 8
        jae m11_diagnostic_bad
        shl bx, 1
        mov ax, [cs:pc88va_m11_character_]
        mov [cs:pc88va_m11_history_+bx], ax
        inc word [cs:pc88va_m11_count_]
        ; The delayed no-input control observes getc alone, without echo.
        cmp byte [cs:pc88va_m11_control_], 1
        je m11_after_echo
        cmp al, 8
        je m11_after_echo
        call pc88va_console_putc_
        or ax, ax
        jnz m11_diagnostic_bad
        cmp word [cs:pc88va_m11_character_], 13
        jne m11_after_echo
        mov ax, 10
        call pc88va_console_putc_
        or ax, ax
        jnz m11_diagnostic_bad
pc88va_m11_k8:
m11_after_echo:
        loop m11_next
        ; A completed sample must not return the held/released last key twice.
        mov ax, pc88va_m11_character_
        call pc88va_console_getc_
        cmp ax, 1
        jne m11_diagnostic_bad
pc88va_m11_k9:
        xor ax, ax
        ret
m11_no_input:
        cmp word [cs:pc88va_m11_empty_count_], 0ffffh
        je m11_next
        inc word [cs:pc88va_m11_empty_count_]
        jmp m11_next
m11_diagnostic_bad:
        mov ax, 0ffffh
        ret
pc88va_m11_control_: db 0
pc88va_m11_count_: dw 0
pc88va_m11_empty_count_: dw 0
pc88va_m11_history_: times 8 dw 0
db 'M11SERVICE:CONSOLE_GETC:MATRIX_POLL', 0
%endif
