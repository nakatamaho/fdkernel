; SPDX-License-Identifier: GPL-2.0-or-later
; M12: resident read-only block service after M10/M11 startup.
;
; The request record and destination buffer are kernel-owned storage.  The
; M08 parameterized core remains the single validator/transfer state machine;
; this file supplies the resident entry and the accepted firmware callback.
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

segment _TEXT class=CODE public use16

extern pc88va_disk_read_core
extern pc88va_m10_state_
extern pc88va_console_putc_

global pc88va_kernel_disk_read_
global pc88va_kernel_firmware_read_one_
global pc88va_m12_prepare_
global pc88va_m12_diagnostic_
global pc88va_m12_control_
global pc88va_m12_request_
global pc88va_m12_result_
global pc88va_m12_buffer_
global pc88va_m12_drive_context_
global pc88va_m12_call_flags_
global pc88va_m12_storage_begin
global pc88va_m12_storage_end

; AX points only to the exported resident request.  AX returns the M08 typed
; status.  The entry is non-reentrant and preserves the caller frame.
pc88va_kernel_disk_read_:
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
        jnz .bad
        mov bx, ds
        mov dx, cs
        cmp bx, dx
        jne .bad
        cmp byte [cs:pc88va_m10_state_], 2
        jne .bad
        cmp ax, pc88va_m12_request_
        jne .bad
        mov si, ax
        call pc88va_disk_read_core
        jmp short .return
.bad:
        mov ax, 1
.return:
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

; Accepted M08 firmware route.  The controller owns the transfer and writes
; directly to the validated ES:BP destination supplied by the core.  The
; callback returns AX=0 and CX=sector bytes only after the firmware reports
; success; no write/format command is reachable from this entry.
pc88va_kernel_firmware_read_one_:
        mov ax, [si+40]
        mov es, ax
        mov bp, [si+38]
        mov bh, [si+32]
        mov bl, [si+34]
        mov cx, [si+32]
        shl cx, 1
        or cx, [si+34]
        mov ax, [si+20]
        mov ch, al
        mov dh, [si+36]
        mov dl, 3
        mov ax, 8101h
        push word [cs:pc88va_m12_call_flags_]
        popf
        int 80h
        jc .firmware_error
        or ah, ah
        jnz .firmware_error
        xor ax, ax
        mov cx, [si+18]
        retf
.firmware_error:
        mov ax, 5
        xor cx, cx
        retf

; Initialize the reusable record for one bounded resident request.  The
; caller may replace LBA/COUNT before invoking pc88va_kernel_disk_read_.
pc88va_m12_prepare_:
        mov word [cs:pc88va_m12_request_+0], 1
        ; The deterministic M12 fixture occupies sectors 200 and 201.
        mov word [cs:pc88va_m12_request_+2], 200
        mov word [cs:pc88va_m12_request_+4], 2
        mov word [cs:pc88va_m12_request_+6], pc88va_m12_buffer_
        mov word [cs:pc88va_m12_request_+8], cs
        mov word [cs:pc88va_m12_request_+10], pc88va_m12_buffer_end-pc88va_m12_buffer_
        mov word [cs:pc88va_m12_request_+12], 1280
        mov word [cs:pc88va_m12_request_+14], 8
        mov word [cs:pc88va_m12_request_+16], 2
        mov word [cs:pc88va_m12_request_+18], 1024
        mov ax, [cs:pc88va_m12_drive_context_]
        mov [cs:pc88va_m12_request_+20], ax
        mov word [cs:pc88va_m12_request_+22], pc88va_kernel_firmware_read_one_
        mov word [cs:pc88va_m12_request_+24], cs
        mov word [cs:pc88va_m12_request_+26], 3
        mov word [cs:pc88va_m12_request_+28], 0
        mov word [cs:pc88va_m12_request_+30], 0
        ret

; Qualification caller.  It is selected by an explicit control byte and is
; reached only after the normal M11 diagnostic has returned.  It records the
; status and completed bytes but never fabricates a successful result.
pc88va_m12_diagnostic_:
        cmp byte [cs:pc88va_m12_control_], 0
        je .disabled
        cmp byte [cs:pc88va_m12_control_], 3
        ja .disabled
        call pc88va_m12_prepare_
        cmp byte [cs:pc88va_m12_control_], 2
        jne .invoke
        ; Control 2 is a deliberately invalid post-boot range.  It must be
        ; rejected by the shared validator before the firmware callback.
        mov word [cs:pc88va_m12_request_+2], 1279
        mov word [cs:pc88va_m12_request_+4], 2
.invoke:
        mov ax, pc88va_m12_request_
        call pc88va_kernel_disk_read_
        mov [cs:pc88va_m12_result_+0], ax
        mov ax, [cs:pc88va_m12_request_+28]
        mov [cs:pc88va_m12_result_+2], ax
        cmp word [cs:pc88va_m12_result_+0], 0
        jne .done
        mov si, pc88va_m12_ok_message
.print:
        xor ax, ax
        mov al, [cs:si]
        inc si
        or al, al
        jz .done
        call pc88va_console_putc_
        or ax, ax
        jz .print
        mov word [cs:pc88va_m12_result_+0], 1
.done:
        mov ax, [cs:pc88va_m12_result_+0]
        ret
.disabled:
        xor ax, ax
        ret

pc88va_m12_ok_message: db 'M12 READ OK', 13, 10, 0
pc88va_m12_service_marker: db 'M12SERVICE:DISK_READ:RESIDENT', 0
pc88va_m12_control_: db 0
pc88va_m12_drive_context_: dw 0
pc88va_m12_call_flags_: dw 0
pc88va_m12_request_: times 48 db 0
pc88va_m12_result_: times 4 db 0
align 16, db 0
pc88va_m12_storage_begin:
pc88va_m12_buffer_: times 4096 db 0
pc88va_m12_buffer_end:
pc88va_m12_storage_end:
