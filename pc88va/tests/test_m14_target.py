#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Structural M14 checks for the PC-88VA write boundary."""

from __future__ import annotations

import unittest
from pathlib import Path


TARGET = Path(__file__).resolve().parents[1]


class M14TargetTests(unittest.TestCase):
    def test_write_core_is_shared_with_the_resident_entry(self):
        resident = (TARGET / "kernel/resident_disk.asm").read_text(encoding="utf-8")
        core = (TARGET / "boot/disk_write.inc").read_text(encoding="utf-8")
        adapter = (TARGET / "kernel/m13_platform.asm").read_text(encoding="utf-8")
        self.assertIn('%include "disk_write.inc"', resident)
        self.assertIn("pc88va_disk_write_core", resident)
        self.assertIn("call pc88va_disk_write_core", resident)
        self.assertIn("pc88va_kernel_firmware_write_one_", resident)
        self.assertIn("global FL_WRITE", adapter)
        self.assertIn("global FL_VERIFY", adapter)
        self.assertIn("8201h", resident)
        self.assertIn("RD_COMPLETED", core)

    def test_write_boundary_is_validated_and_bounded(self):
        core = (TARGET / "boot/disk_write.inc").read_text(encoding="utf-8")
        for text in ("RD_VERSION", "RD_TOTAL_SECTORS", "RD_COUNT",
                     "RD_CAPACITY", "RD_CURRENT_OFFSET", "RD_RETRIES_LEFT",
                     "DISK_RANGE", "DISK_CAPACITY", "DISK_SHORT"):
            self.assertIn(text, core)
        adapter = (TARGET / "kernel/m13_platform.asm").read_text(encoding="utf-8")
        self.assertIn("cmp di, 0xfc00", adapter)
        self.assertIn("retf 14", adapter)

    def test_va_status_and_change_contract_are_not_silent_success(self):
        adapter = (TARGET / "kernel/m13_platform.asm").read_text(encoding="utf-8")
        self.assertIn("mov ah, 09h", adapter)
        self.assertIn("pc88va_map_va_write_status", adapter)
        self.assertIn("mov ax, 3", adapter)
        self.assertIn("mov ax, 80h", adapter)
        self.assertIn("mov ax, 10h", adapter)

    def test_resident_write_object_dependency_is_explicit(self):
        makefile = (TARGET / "makefile.m13.wc").read_text(encoding="utf-8")
        self.assertIn("boot/disk_write.inc", makefile)


if __name__ == "__main__":
    unittest.main()
