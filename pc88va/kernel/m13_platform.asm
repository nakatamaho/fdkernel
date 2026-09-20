; SPDX-License-Identifier: GPL-2.0-or-later
; PC-88VA adapter for the common FreeDOS block and clock interfaces.
;
; The adapter owns no filesystem policy.  It translates the common driver
; request to the resident M12 read ABI and refuses every write/format path.
bits 16
cpu 8086

%include "../hdr/stacks.inc"
%include "boot/loader_abi.inc"

; The common arg macro starts at BP+4 for a near return frame.  These
; platform entry points are called FAR by the medium-model C caller, so their
; first argument starts at BP+6 (the extra word is the return CS).
%macro pc88va_arg_far 1-*
        %assign .argloc 6
        %rep %0
                %ifdef PASCAL
                        %rotate -1
                %endif
                        definearg %1
                %ifdef STDCALL
                        %rotate 1
                %endif
        %endrep
%endmacro

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
extern pc88va_kernel_firmware_read_one_
extern pc88va_m12_request_
extern pc88va_m12_buffer_
extern pc88va_m12_drive_context_
extern _int21_service
extern entry

%include "kernel/m13_segments.inc"
segment M13_PLATFORM_TEXT

; HMA_TEXT invokes the common INT 21 service through a FAR transfer after
; relocation.  The Open Watcom medium-model C body is a FAR CDECL function.
; Entry has the user register-frame words (BP then SS) below the synthetic
; FAR return frame; rebuild that one far argument explicitly before calling
; the C body and remove it after the CDECL return.  This keeps the outer
; entry/IRET frame byte-for-byte intact.
global _pc88va_int21_service_far
global pc88va_int21_service_far_
_pc88va_int21_service_far:
pc88va_int21_service_far_:
        push bp
        mov bp, sp
        ; wrapper entry: [bp+2] outer IP, [bp+4] outer CS,
        ; [bp+6] user BP (pointer offset), [bp+8] user SS (segment).
        push word [bp+8]
        push word [bp+6]
        call far _int21_service
        add sp, 4
        pop bp
        retf

; Read the PC-88VA BIOS main-memory selection from backup RAM.  The BIOS
; record is exposed at B000:1FC4 when system-memory bank 9 is selected in the
; high byte of the 0152h word port.  Keep the port word and segment mapping
; transactionally paired: an interrupt must not observe the temporary bank.
global PC88VA_MEMORY_KB
PC88VA_MEMORY_KB:
        pushf
        cli
        push bx
        push dx
        push si
        push es

        mov dx, 0152h
        in ax, dx
        push ax
        and ah, 0f0h
        or ah, 09h
        out dx, ax

        mov ax, 0b000h
        mov es, ax
        mov al, [es:1fc4h]
        and al, 07h
        ; VAEG and the supported VA BIOS record encode 256, 384, 512,
        ; and 640 KiB as codes 1..4.  Reject an erased/open-bus record
        ; instead of fabricating a larger memory ceiling.
        cmp al, 4
        ja .memory_invalid
        or al, al
        jz .memory_invalid
        inc al
        mov bl, 128
        mul bl
        mov si, ax
        jmp short .memory_restore

.memory_invalid:
        xor si, si

.memory_restore:
        mov dx, 0152h
        pop ax
        out dx, ax
        mov ax, si
        pop es
        pop si
        pop dx
        pop bx
        popf
        retf

; Return the segment where the MZ loader placed the initial kernel image.
; `entry` is the zero-offset PSP/MZ entry, so its relocated segment is the
; image base even though the common resident text is later copied elsewhere.
global PC88VA_IMAGE_SEGMENT
PC88VA_IMAGE_SEGMENT:
        mov ax, seg entry
        retf

; DOS clock hooks use the PC-88VA calendar BIOS.  INT 8Ch/AH=02 returns the
; current binary hour in CH, minute in CL, and second in DH.  The common
; CLOCK$ code expects the IBM-compatible PIT tick count in DX:AX, so convert
; seconds since midnight using the same 1,193,180-Hz scale as sysclk.c.
; Keep the FAR medium-model ABI and preserve every register outside the
; declared AX/CX/DX result set.
global READPCCLOCK
READPCCLOCK:
        push bx
        push si
        push di
        push bp
        push ds
        push es
        mov ah, 02h
        int 8ch

        ; Form seconds since midnight in DX:AX.  The BIOS fields are binary.
        xor bx, bx
        mov bl, dh
        mov si, bx
        xor dx, dx
        xor ax, ax
        mov al, ch
        mov bl, 60
        mul bl
        xor bx, bx
        mov bl, cl
        add ax, bx
        mov bx, 60
        mul bx
        add ax, si
        adc dx, 0

        ; 1,193,180 = 18*65,536 + 13,532.  Keep the 18*s term while
        ; calculating floor(s*13,532/65,536) with 16-bit MUL operations.
        mov si, ax
        mov bx, dx
        mov ax, si
        mov dx, bx
        shl ax, 1
        rcl dx, 1
        mov di, ax
        mov bp, dx
        shl ax, 1
        rcl dx, 1
        shl ax, 1
        rcl dx, 1
        shl ax, 1
        rcl dx, 1
        add ax, di
        adc dx, bp
        push dx
        push ax

        mov ax, si
        mov cx, 13532
        mul cx
        mov di, dx
        mov ax, bx
        mul cx
        add ax, di
        adc dx, 0
        pop cx
        pop bx
        add cx, ax
        adc bx, dx
        mov ax, cx
        mov dx, bx

        pop es
        pop ds
        pop bp
        pop di
        pop si
        pop bx
        ; Medium-model C callers enter through a synthetic FAR call
        ; (push CS followed by a near call).  Consume both return words;
        ; a near RET would leave the return segment on caller stack.
        retf

global WRITEPCCLOCK
WRITEPCCLOCK:
        ; VOID Pascal(ULONG): two argument words, FAR caller frame.
        retf 4

global WRITEATCLOCK
WRITEATCLOCK:
        ; VOID Pascal(BYTE *, BYTE, BYTE, BYTE): four argument words.
        ; The pointer is NEAR data even though the code call is FAR.
        retf 8

; BOOL fl_reset(WORD drive).  The medium-model Pascal caller supplies one
; word below the FAR return frame.  This read-only adapter has no reset
; operation; retain the zero result without removing either return word.
global FL_RESET
FL_RESET:
        xor ax, ax
        retf 2

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
        pc88va_arg_far drive, head, track, sector, count, {buffer,4}
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
        ; The resident validator requires an explicit qualified far adapter.
        ; Keep the callback binding in the request built for each DOS read;
        ; a zero binding is a contract error, not a firmware result.
        mov word [cs:pc88va_m12_request_+RD_ADAPTER_OFFSET], pc88va_kernel_firmware_read_one_
        mov word [cs:pc88va_m12_request_+RD_ADAPTER_SEGMENT], cs
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
        retf 14

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
