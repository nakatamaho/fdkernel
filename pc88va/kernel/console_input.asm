; SPDX-License-Identifier: GPL-2.0-or-later
; M11: firmware queue polling, no echo and no second queue.
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
segment _TEXT class=CODE public use16
extern pc88va_m10_state_
extern pc88va_console_putc_
%endif
global pc88va_console_getc_, pc88va_m11_character_
global pc88va_m11_poll_bios, pc88va_m11_take_bios, pc88va_m11_return

; Near Watcom register ABI: AX = &pc88va_m11_character_, DS = CS,
; M10 ready, IF=DF=0. AX: 0 character, 1 empty, 2 unsupported consumed,
; ffff invalid precondition. The word is written only for status zero.
; All other registers, segments, architectural FLAGS and SP are preserved.
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
        test word [ss:bp+16], 0600h
        jnz m11_bad
        cmp ax, pc88va_m11_character_
        jne m11_bad
        mov bx, ds
        mov dx, cs
        cmp bx, dx
        jne m11_bad
        cmp byte [cs:pc88va_m10_state_], 2
        jne m11_bad
        xor bx, bx
        mov es, bx
        mov bx, [es:82h*4]
        or bx, [es:82h*4+2]
        jz m11_bad
pc88va_m11_poll_bios:
        mov ah, 0ah
        int 82h
        jc m11_empty
pc88va_m11_take_bios:
        mov ah, 09h
        int 82h
        cmp al, 08h
        je m11_character
        cmp al, 0dh
        je m11_character
        cmp al, 20h
        jb m11_unsupported
        cmp al, 7eh
        ja m11_unsupported
m11_character:
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

pc88va_m11_character_: dw 0

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
db 'M11SERVICE:CONSOLE_GETC:KEYBOARD_BIOS', 0
%endif
