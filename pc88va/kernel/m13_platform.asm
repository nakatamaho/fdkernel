; SPDX-License-Identifier: GPL-2.0-or-later
; PC-88VA adapter for the common FreeDOS block and clock interfaces.
;
; The adapter owns no filesystem policy.  It translates the common driver
; request to the resident M12 read ABI and refuses every write/format path.
bits 16
cpu 8086

%include "../kernel/segs.inc"
%include "../hdr/stacks.inc"
%include "boot/loader_abi.inc"

%ifndef PC88VA
%error PC88VA selector is required
%endif
%ifdef NEC98
%error Mixed machine selectors
%endif
%ifdef IBMPC
%error Mixed machine selectors
%endif

extern pc88va_kernel_disk_read_
extern pc88va_m12_request_
extern pc88va_m12_buffer_
extern pc88va_m12_drive_context_

segment _TEXT class=CODE public use16

; Conventional-memory adapter value.  This is a bounded platform contract,
; not a claim that the host has a particular amount of RAM.
global PC88VA_MEMORY_KB
PC88VA_MEMORY_KB:
        mov ax, 640
        ret

; DOS clock hooks use the accepted M10 monotonic service boundary.  The
; deterministic public build starts at zero; no RTC or I/O port is touched.
global READPCCLOCK
READPCCLOCK:
        xor dx, dx
        xor ax, ax
        ret

global WRITEPCCLOCK
WRITEPCCLOCK:
        ret 4

global WRITEATCLOCK
WRITEATCLOCK:
        ret 10

; BOOL fl_reset(WORD drive)
global FL_RESET
FL_RESET:
        pop ax
        pop dx
        push ax
        xor ax, ax
        ret

; COUNT fl_diskchanged(WORD drive): no media-change event is synthesized.
global FL_DISKCHANGED
FL_DISKCHANGED:
        pop ax
        pop dx
        push ax
        xor ax, ax
        ret

; Common driver read: drive, head, cylinder, sector, count, ES:BX buffer.
; M12 accepts at most four 1024-byte sectors per request.  The loop preserves
; completed sectors and copies only the validated resident bytes to the DOS
; caller.  Segment wrap is rejected before a copy.
global FL_READ
FL_READ:
        push bp
        mov bp, sp
        push ds
        push si
        push di
        push bx
        push cx
        push dx
        push es
        arg drive, head, track, sector, count, {buffer,4}
        mov ax, [.drive]
        or ax, ax
        jnz .bad
        mov ax, [.head]
        cmp ax, 2
        jae .bad
        mov ax, [.sector]
        cmp ax, 1
        jb .bad
        cmp ax, 8
        ja .bad
        mov ax, [.count]
        or ax, ax
        jz .bad
        mov cx, ax
        mov dx, [.track]
        cmp dx, 160
        jae .bad
        ; lba = ((cylinder * 2 + head) * 8) + (sector - 1)
        shl dx, 1
        add dx, [.head]
        shl dx, 1
        shl dx, 1
        add dx, [.sector]
        dec dx
        mov si, dx
        add dx, cx
        cmp dx, 1280
        ja .bad
        les di, [.buffer]
.next:
        cmp di, 0xfc00
        jae .bad
        mov word [cs:pc88va_m12_request_+RD_VERSION], 1
        mov word [cs:pc88va_m12_request_+RD_LBA], si
        mov word [cs:pc88va_m12_request_+RD_COUNT], 1
        mov word [cs:pc88va_m12_request_+RD_OFFSET], pc88va_m12_buffer_
        mov word [cs:pc88va_m12_request_+RD_SEGMENT], cs
        mov word [cs:pc88va_m12_request_+RD_CAPACITY], 4096
        mov word [cs:pc88va_m12_request_+RD_TOTAL_SECTORS], 1280
        mov word [cs:pc88va_m12_request_+RD_SECTORS_TRACK], 8
        mov word [cs:pc88va_m12_request_+RD_HEADS], 2
        mov word [cs:pc88va_m12_request_+RD_SECTOR_BYTES], 1024
        mov ax, [cs:pc88va_m12_drive_context_]
        mov word [cs:pc88va_m12_request_+RD_DRIVE_CONTEXT], ax
        mov word [cs:pc88va_m12_request_+RD_RETRIES], 3
        mov word [cs:pc88va_m12_request_+RD_COMPLETED], 0
        mov ax, pc88va_m12_request_
        push ds
        push cs
        pop ds
        call pc88va_kernel_disk_read_
        pop ds
        or ax, ax
        jnz .bad
        push cx
        push ds
        push cs
        pop ds
        mov si, pc88va_m12_buffer_
        mov dx, 512
        mov cx, dx
        cld
        rep movsw
        pop ds
        pop cx
        ; SI is the source scratch pointer; recover the next LBA from the
        ; request record rather than relying on the copied-byte count.
        mov si, [cs:pc88va_m12_request_+RD_LBA]
        inc si
        dec cx
        jnz .next
        xor ax, ax
        jmp short .return
.bad:
        mov ax, 5                 ; DOS write-protect/general I/O error
.return:
        pop es
        pop dx
        pop cx
        pop bx
        pop di
        pop si
        pop ds
        pop bp
        ret 14

; Every mutating or unsupported low-level operation is rejected before any
; resident callback can run.  The common DOS layer maps this to its documented
; write-protect/error status.
%macro reject_word 2
global %1
%1:
        pop ax
        %if %2 > 0
        add sp, %2
        %endif
        push ax
        mov ax, 5
        ret
%endmacro

reject_word FL_WRITE, 12
reject_word FL_FORMAT, 12
reject_word FL_VERIFY, 12
reject_word FL_SETDISKTYPE, 4
reject_word FL_SETMEDIATYPE, 6
reject_word FL_LBA_READWRITE, 8

global FL_READKEY
FL_READKEY:
        xor ax, ax
        ret

global FLOPPY_CHANGE
FLOPPY_CHANGE:
        mov ax, 0ffffh
        ret
