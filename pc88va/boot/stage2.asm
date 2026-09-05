; SPDX-License-Identifier: GPL-2.0-or-later
; Parameterized stage-2 entry, workspace and real disk/FAT12/MZ loader.
; Required preinclude: validated profile definitions and firmware adapter macro.
bits 16
cpu 8086
org 0
%include "loader_abi.inc"
%ifndef PC88VA_PROFILE_VERSION
%error A validated loader profile is required
%endif
%if PC88VA_PROFILE_VERSION != 1
%error Unsupported loader profile
%endif
%ifndef PC88VA
%error PC88VA selector is required
%endif
%ifnmacro PC88VA_FIRMWARE_READ_ONE 0
%error A qualified firmware callback or explicit ROM-free fixture is required
%endif

pc88va_stage2_entry:
    ; Stage 1 provides CS at the image base, DX=opaque drive, BX=call FLAGS.
    ; Do not depend on the incoming data segment or stack.
    cli
    mov ax, cs
    cmp ax, S2_STAGE2_SEGMENT
    jne pc88va_stage2_fail
    mov ds, ax
    mov [pc88va_stage2_disk+RD_DRIVE_CONTEXT], dx
    mov [pc88va_stage2_call_flags], bx
    mov [pc88va_stage2_disk+RD_ADAPTER_SEGMENT], ax
    mov ax, S2_STACK_SEGMENT
    mov ss, ax
    mov sp, S2_STACK_POINTER
    cld
    mov si, pc88va_stage2_boot
    call pc88va_boot_load_core
pc88va_stage2_fail:
    cli
    jmp short pc88va_stage2_fail

pc88va_stage2_adapter:
%define PC88VA_CALL_FLAGS pc88va_stage2_call_flags
    PC88VA_FIRMWARE_READ_ONE

%include "disk_read.inc"
%include "volume_validate.inc"
%include "volume_read.inc"
%include "fat12.inc"
%include "root_directory.inc"
%include "file_load.inc"
%include "loader_handoff.inc"
%include "boot_load.inc"

align 2, db 0
pc88va_stage2_call_flags: dw 0
pc88va_stage2_boot:
    dw 1, pc88va_stage2_metadata, pc88va_stage2_mz, 0, 0
pc88va_stage2_metadata:
    dw 1, pc88va_stage2_disk, pc88va_stage2_volume, pc88va_stage2_fat
    dw pc88va_stage2_root, pc88va_stage2_file
    dw S2_MIRROR_OFFSET, S2_SCRATCH_SEGMENT, S2_FAT_CAPACITY, 0
pc88va_stage2_disk:
    dw 1, 0, 1, S2_BOOT_OFFSET, S2_SCRATCH_SEGMENT, S2_SECTOR_BYTES
    dw S2_TOTAL_SECTORS, S2_SECTORS_TRACK, S2_HEADS, S2_SECTOR_BYTES
    dw 0, pc88va_stage2_adapter, 0, 0
    times 10 dw 0
pc88va_stage2_volume:
    dw 1, S2_BOOT_OFFSET, S2_SCRATCH_SEGMENT, S2_SECTOR_BYTES, pc88va_stage2_disk
    dw S2_FAT_CAPACITY, S2_ROOT_CAPACITY, S2_BITMAP_CAPACITY
    times 14 dw 0
pc88va_stage2_fat:
    dw 1, S2_FAT_OFFSET, S2_SCRATCH_SEGMENT, S2_FAT_CAPACITY, 0, 0, 0
    dw S2_BITMAP_OFFSET, S2_SCRATCH_SEGMENT, S2_BITMAP_CAPACITY, 0, 0, 0
pc88va_stage2_root:
    dw 1, S2_ROOT_OFFSET, S2_SCRATCH_SEGMENT, 0, S2_ROOT_CAPACITY
    dw 0, S2_KERNEL_FILE_CAPACITY, 0, 0, 0
pc88va_stage2_file:
    dw 1, pc88va_stage2_disk, pc88va_stage2_fat, pc88va_stage2_root
    dw 0, S2_KERNEL_FILE_SEGMENT, S2_KERNEL_FILE_CAPACITY, 0, 0
    dw S2_BOOT_OFFSET, S2_SCRATCH_SEGMENT, S2_SECTOR_BYTES
    times 9 dw 0
pc88va_stage2_mz:
    dw 1, 0, S2_KERNEL_FILE_SEGMENT, 0
    dw S2_KERNEL_ALLOCATION_SEGMENT, S2_KERNEL_ALLOCATION_CAPACITY, 256, 0
%assign S2_PROTECTED_COUNT 0
%if S2_KERNEL_ALLOCATION_SEGMENT > 0
%assign S2_PROTECTED_COUNT S2_PROTECTED_COUNT + 1
%endif
%if (S2_KERNEL_ALLOCATION_SEGMENT * 16 + S2_KERNEL_ALLOCATION_CAPACITY) < 0x100000
%assign S2_PROTECTED_COUNT S2_PROTECTED_COUNT + 1
%endif
    dw pc88va_stage2_protected, S2_PROTECTED_COUNT
    times 17 dw 0
pc88va_stage2_protected:
    ; Protect everything except the one explicitly owned kernel allocation.
%if S2_KERNEL_ALLOCATION_SEGMENT > 0
    dd 0, S2_KERNEL_ALLOCATION_SEGMENT * 16
%endif
%if (S2_KERNEL_ALLOCATION_SEGMENT * 16 + S2_KERNEL_ALLOCATION_CAPACITY) < 0x100000
    dd S2_KERNEL_ALLOCATION_SEGMENT * 16 + S2_KERNEL_ALLOCATION_CAPACITY, 0x100000
%endif

; Project-owned symbol footer: the build/evidence extractor checks these offsets.
pc88va_stage2_symbols:
    db 'M08S2SYM'
    dw 1, pc88va_stage2_entry, pc88va_stage2_fail, pc88va_stage2_adapter
    dw pc88va_stage2_boot, pc88va_stage2_metadata, pc88va_stage2_disk
    dw pc88va_stage2_volume, pc88va_stage2_fat, pc88va_stage2_root
    dw pc88va_stage2_file, pc88va_stage2_mz, pc88va_stage2_call_flags
    dw pc88va_stage2_end
pc88va_stage2_end:
%if (pc88va_stage2_end - $$) > S2_STAGE2_CAPACITY
%error Stage-2 image exceeds its validated ownership interval
%endif
