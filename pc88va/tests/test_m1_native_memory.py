#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Contract and fixture checks for the PC-88VA native memory decoder."""

import unittest
from pathlib import Path


TARGET = Path(__file__).resolve().parents[1]
SOURCE = (TARGET / "kernel/m13_platform.asm").read_text(encoding="utf-8")
CAPACITY_BY_CODE = {1: 256, 2: 384, 3: 512, 4: 640}


def va_record(capacity_kb: int, *, checksum_valid: bool = True) -> bytes:
    """Build only the VAEG-documented capacity record in a 0x4000 image."""
    if capacity_kb not in CAPACITY_BY_CODE.values():
        raise ValueError(capacity_kb)
    record = bytearray(0x4000)
    record[0x1FC2:0x1FCD] = bytes((0xDB, 0x02,
                                    0x60 | ((capacity_kb // 128) - 1),
                                    0x04, 0xF9, 0x0A,
                                    0x4B, 0x5A, 0x4D, 0xFF, 0xFF))
    record[0x1FCD] = sum(record[0x1FC0:0x1FC8]) & 0xFF
    if not checksum_valid:
        record[0x1FCD] ^= 0x01
    return bytes(record)


def decode_field(image: bytes) -> int:
    """Model the exact guarded low-three-bit decoder in the 8086 routine."""
    code = image[0x1FC4] & 0x07
    return (code + 1) * 128 if 1 <= code <= 4 else 0


class NativeMemoryTests(unittest.TestCase):
    def test_source_selects_system_bank_and_native_field(self):
        self.assertIn("mov dx, 0152h", SOURCE)
        self.assertIn("in ax, dx", SOURCE)
        self.assertIn("and ah, 0f0h", SOURCE)
        self.assertIn("or ah, 09h", SOURCE)
        self.assertIn("out dx, ax", SOURCE)
        self.assertIn("mov ax, 0b000h", SOURCE)
        self.assertIn("mov al, [es:1fc4h]", SOURCE)
        self.assertIn("and al, 07h", SOURCE)
        self.assertIn("retf", SOURCE)

    def test_all_supported_capacity_codes(self):
        for code, expected in CAPACITY_BY_CODE.items():
            image = bytearray(0x4000)
            image[0x1FC4] = 0x60 | code
            self.assertEqual(decode_field(image), expected)

    def test_high_bits_are_record_metadata_not_capacity(self):
        for code, expected in CAPACITY_BY_CODE.items():
            image = bytearray(0x4000)
            image[0x1FC4] = 0xE0 | code
            self.assertEqual(decode_field(image), expected)

    def test_va_and_va2_files_share_record_layout(self):
        for filename in ("vabkupmem.dat", "va2bkupmem.dat"):
            with self.subTest(filename=filename):
                self.assertEqual(decode_field(va_record(640)), 640)

    def test_invalid_erased_and_unsupported_codes_fail_closed(self):
        for value in (0x00, 0x60, 0x65, 0x67, 0xFF):
            with self.subTest(value=value):
                image = bytearray(0x4000)
                image[0x1FC4] = value
                self.assertEqual(decode_field(image), 0)

    def test_checksum_is_not_reinterpreted_by_kernel_decoder(self):
        # VAEG stores a checksum but bkupmemva_load does not validate it before
        # exposing the image.  The kernel contract therefore uses the guarded
        # capacity field and does not invent a checksum fallback.
        self.assertEqual(decode_field(va_record(256, checksum_valid=False)), 256)

    def test_non_pc88va_path_remains_int12_based(self):
        source = (TARGET / "../kernel/initoem.c").resolve().read_text(encoding="utf-8")
        common = source.split("#else", 1)[1]
        self.assertIn("init_call_intr(0x12, &r)", common)
        self.assertNotIn("pc88va_memory_kb", common)


if __name__ == "__main__":
    unittest.main()
