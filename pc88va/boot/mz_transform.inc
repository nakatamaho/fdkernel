; SPDX-License-Identifier: GPL-2.0-or-later
; Copy and verify a validated zero-relocation body into its owned allocation.
bits 16
cpu 8086
    jmp pc88va_mz_transform_core
%include "mz_validate.inc"

pc88va_mz_transform_core:
    pushf
    push bx
    push cx
    push dx
    push di
    push bp
    push es
    call pc88va_mz_validate_core
    or ax, ax
    jnz .restore
    cld
    mov es, [si+MZ_LOAD_SEGMENT]
    xor di, di
    mov cx, [si+MZ_BODY_BYTES]
    call .source
    rep movsb
    pop si
    pop ds
    mov cx, [si+MZ_ALLOC_BYTES]
    sub cx, [si+MZ_BODY_BYTES]
    xor ax, ax
    rep stosb
    ; Compare the initialized body against the original file, not a checksum.
    xor di, di
    mov cx, [si+MZ_BODY_BYTES]
    call .source
    repe cmpsb
    pop si
    pop ds
    jne .bytecheck
    ; Verify the full rounded body padding and minimum allocation tail.
    mov cx, [si+MZ_ALLOC_BYTES]
    sub cx, [si+MZ_BODY_BYTES]
    jcxz .complete
    xor ax, ax
    repe scasb
    jne .bytecheck
.complete:
    mov word [si+MZ_TRANSFORMED], 1
    xor ax, ax
    jmp .restore
.bytecheck:
    mov ax, MZ_BYTECHECK
.restore:
    pop es
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    or ax, ax
    jnz .error
    popf
    clc
    ret
.error:
    popf
    stc
    ret

; Switch to file DS:SI while leaving the caller's DS/SI on its original stack.
; Pop the near return address before adding the two saved words.
.source:
    pop bp
    push ds
    push si
    mov ax, [si+MZ_FILE_SEGMENT]
    mov bx, [si+MZ_FILE_OFFSET]
    add bx, [si+MZ_HEADER_BYTES]
    mov si, bx
    mov ds, ax
    jmp bp
