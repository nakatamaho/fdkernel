; SPDX-License-Identifier: GPL-2.0-or-later
; M13 resident unpack bridge for a large common FreeDOS kernel.
;
; The accepted M08 carrier has one 16-bit transformed allocation.  This
; bridge keeps that carrier bounded by storing an LZSS-compressed common
; kernel in it, then expands the exact body into the adjacent, separately
; owned loader-stack interval before entering the original MZ entry.  The
; source payload is copied to the kernel-owned scratch interval first, so
; expansion never reads bytes it is overwriting.
bits 16
cpu 8086
org 0

%ifndef M13_LOAD_SEG
%error M13_LOAD_SEG is required
%endif
%ifndef M13_FILE_SEG
%error M13_FILE_SEG is required
%endif
%ifndef M13_SCRATCH_SEG
%error M13_SCRATCH_SEG is required
%endif
%ifndef M13_PAYLOAD_OFFSET
%error M13_PAYLOAD_OFFSET is required
%endif
%ifndef M13_PAYLOAD_SIZE
%error M13_PAYLOAD_SIZE is required
%endif
%ifndef M13_DATA_SIZE
%error M13_DATA_SIZE is required
%endif
%ifndef M13_RELOC_SOURCE_OFFSET
%error M13_RELOC_SOURCE_OFFSET is required
%endif
%ifndef M13_RELOC_COUNT
%error M13_RELOC_COUNT is required
%endif
%ifndef M13_OUTPUT_SIZE
%error M13_OUTPUT_SIZE is required
%endif
%ifndef M13_ORIG_SS
%error M13_ORIG_SS is required
%endif
%ifndef M13_ORIG_SP
%error M13_ORIG_SP is required
%endif
%ifndef M13_ORIG_CS
%error M13_ORIG_CS is required
%endif
%ifndef M13_ORIG_IP
%error M13_ORIG_IP is required
%endif

%define M13_RING_OFFSET 60000
%define M13_RING_BYTES 4096

; The bootstrap runs at the transformed allocation base.  It moves this
; bridge to the immutable kernel-file segment before any output is written.
m13_unpack_start:
    cli
    mov ax, M13_LOAD_SEG
    mov ds, ax
    mov [cs:m13_saved_dx], dx
    mov ax, M13_FILE_SEG
    mov es, ax
    xor si, si
    xor di, di
    mov cx, m13_unpack_end - m13_unpack_start
    rep movsb
    mov ax, M13_FILE_SEG
    push ax
    mov ax, m13_unpack_run
    push ax
    retf

m13_unpack_run:
    ; The copied bridge owns a safe stack outside both output intervals.
    mov ax, M13_FILE_SEG
    mov ss, ax
    mov sp, 0xff00
    cld

    ; Copy the compressed payload out of the transformed carrier before
    ; expanding output over that carrier.
    mov ax, M13_LOAD_SEG
    mov ds, ax
    mov si, M13_PAYLOAD_OFFSET
    mov ax, M13_SCRATCH_SEG
    mov es, ax
    xor di, di
    mov cx, M13_DATA_SIZE
    rep movsb

    ; Clear the 4 KiB history window and set DS to the source/ring segment.
    mov ax, M13_SCRATCH_SEG
    mov ds, ax
    mov es, ax
    mov di, M13_RING_OFFSET
    xor al, al
    mov cx, M13_RING_BYTES
    rep stosb
    mov ax, M13_LOAD_SEG
    mov es, ax
    xor di, di
    xor bp, bp
    mov word [cs:m13_source], 0
    mov ax, M13_OUTPUT_LO
    mov [cs:m13_remaining_lo], ax
    mov ax, M13_OUTPUT_HI
    mov [cs:m13_remaining_hi], ax
    mov word [cs:m13_dest_segment], M13_LOAD_SEG
    mov byte [cs:m13_flags], 0
    mov byte [cs:m13_flag_bits], 0

.token:
    cmp word [cs:m13_remaining_hi], 0
    jne .have_output
    cmp word [cs:m13_remaining_lo], 0
    je .complete
.have_output:
    call m13_next_flag
    jc .fail
    test byte [cs:m13_flags], 1
    jnz .match
    call m13_consume_flag

    call m13_next_byte
    jc .fail
    call m13_emit
    jc .fail
    jmp .token

.match:
    call m13_consume_flag
    call m13_next_byte
    jc .fail
    mov bl, al
    call m13_next_byte
    jc .fail
    mov bh, al
    mov ax, bx
    and ah, 0xf0
    mov cl, 4
    shr ah, cl
    mov al, bl
    inc ax
    ; The token stores a backwards distance.  Convert it to the current
    ; ring index before emitting an overlapping match.
    mov dx, ax
    mov ax, bp
    sub ax, dx
    and ax, M13_RING_BYTES - 1
    mov [cs:m13_match_offset], ax
    mov al, bh
    and al, 0x0f
    xor ah, ah
    add ax, 3
    mov [cs:m13_match_length], ax
.match_byte:
    cmp word [cs:m13_match_length], 0
    je .token
    cmp word [cs:m13_remaining_hi], 0
    jne .match_output_ok
    cmp word [cs:m13_remaining_lo], 0
    je .fail
.match_output_ok:
    mov bx, [cs:m13_match_offset]
    add bx, M13_RING_OFFSET
    cmp bx, M13_RING_OFFSET + M13_RING_BYTES
    jb .ring_address
    sub bx, M13_RING_BYTES
.ring_address:
    mov al, [ds:bx]
    call m13_emit
    jc .fail
    inc word [cs:m13_match_offset]
    cmp word [cs:m13_match_offset], M13_RING_BYTES
    jb .match_next
    sub word [cs:m13_match_offset], M13_RING_BYTES
.match_next:
    dec word [cs:m13_match_length]
    jmp .match_byte

.complete:
    ; Apply the original MZ relocation words after the exact body has been
    ; expanded.  The records are copied after the compressed stream.
    mov si, M13_RELOC_SOURCE_OFFSET
    mov cx, M13_RELOC_COUNT
.relocate:
    jcxz .relocated
    mov di, [ds:si]
    mov bx, [ds:si+2]
    mov ax, M13_LOAD_SEG
    add ax, bx
    mov es, ax
    add word [es:di], M13_LOAD_SEG
    add si, 4
    dec cx
    jmp .relocate
.relocated:
    mov ax, M13_LOAD_SEG
    mov es, ax
    mov ax, M13_LOAD_SEG + M13_ORIG_SS
    mov ss, ax
    mov sp, M13_ORIG_SP
    mov ax, M13_LOAD_SEG
    mov ds, ax
    mov es, ax
    mov dx, [cs:m13_saved_dx]
    mov ax, M13_LOAD_SEG + M13_ORIG_CS
    push ax
    mov ax, M13_ORIG_IP
    push ax
    retf

.fail:
    cli
    hlt
    jmp .fail

; Load the next flag bit.  Carry means that the bounded source is exhausted.
m13_next_flag:
    cmp byte [cs:m13_flag_bits], 0
    jne .ready
    cmp word [cs:m13_source], M13_PAYLOAD_SIZE
    jae .bad
    mov bx, [cs:m13_source]
    mov al, [ds:bx]
    mov [cs:m13_flags], al
    inc word [cs:m13_source]
    mov byte [cs:m13_flag_bits], 8
.ready:
    clc
    ret
.bad:
    stc
    ret

m13_consume_flag:
    shr byte [cs:m13_flags], 1
    dec byte [cs:m13_flag_bits]
    ret

; Return one bounded source byte in AL, with carry on exhaustion.
m13_next_byte:
    cmp word [cs:m13_source], M13_PAYLOAD_SIZE
    jae .bad
    mov bx, [cs:m13_source]
    mov al, [ds:bx]
    inc word [cs:m13_source]
    clc
    ret
.bad:
    stc
    ret

; Emit AL to the contiguous real-mode output and to the history ring.
m13_emit:
    cmp word [cs:m13_remaining_hi], 0
    jne .emit_allowed
    cmp word [cs:m13_remaining_lo], 0
    je .bad
.emit_allowed:
    push ax
    mov [es:di], al
    inc di
    jnz .destination_ok
    mov ax, [cs:m13_dest_segment]
    add ax, 0x1000
    mov [cs:m13_dest_segment], ax
    mov es, ax
.destination_ok:
    pop ax
    mov [ds:bp+M13_RING_OFFSET], al
    inc bp
    and bp, M13_RING_BYTES - 1
    sub word [cs:m13_remaining_lo], 1
    jnc .remaining_ok
    dec word [cs:m13_remaining_hi]
.remaining_ok:
    clc
    ret
.bad:
    stc
    ret

m13_saved_dx:       dw 0
m13_source:         dw 0
m13_remaining_lo:   dw 0
m13_remaining_hi:   dw 0
m13_dest_segment:   dw 0
m13_match_offset:   dw 0
m13_match_length:   dw 0
m13_flags:          db 0
m13_flag_bits:      db 0
m13_unpack_end:
