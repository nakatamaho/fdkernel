#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""ROM-free status propagation checks for the resident read callback."""

from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

import unicorn
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn.x86_const import (
    UC_X86_REG_AX, UC_X86_REG_CX, UC_X86_REG_SI, UC_X86_REG_SP,
    UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_EFLAGS,
)

TARGET = Path(__file__).resolve().parents[1]
CODE, STACK, REQUEST, STOP = 0x1200, 0x7000, 0x1000, 0x3f00


class ReadCallbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if unicorn.__version__ != "2.1.4":
            raise RuntimeError("M14 execution QA requires pinned Unicorn 2.1.4")
        resident = (TARGET / "kernel/resident_disk.asm").read_text(encoding="utf-8")
        # Assemble the actual callback instructions, without a synthetic
        # substitute for their firmware-status-to-transfer-core boundary.
        callback = resident.split("pc88va_kernel_firmware_read_one_:\n", 1)[1]
        callback = callback.split("pc88va_kernel_firmware_write_one_:", 1)[0]
        with tempfile.TemporaryDirectory(prefix="m14-read-callback-") as directory:
            source = Path(directory) / "callback.asm"
            binary = Path(directory) / "callback.bin"
            source.write_text("bits 16\ncpu 8086\norg 0\nentry:\n" + callback +
                              "\npc88va_m12_call_flags_: dw 0\n", encoding="utf-8")
            subprocess.run(["nasm", "-f", "bin", "-o", str(binary), str(source)],
                           check=True, capture_output=True)
            cls.code = binary.read_bytes()

    def execute(self, firmware_status, carry):
        machine = Uc(UC_ARCH_X86, UC_MODE_16)
        machine.mem_map(0, 0x100000)
        machine.mem_write(CODE * 16, self.code)
        words = [0] * 24
        words[9], words[18], words[19], words[20] = 1024, 1, 0x2000, CODE
        machine.mem_write(CODE * 16 + REQUEST, struct.pack("<24H", *words))
        machine.mem_write(STACK * 16 + 0x1000, struct.pack("<HH", STOP, CODE))
        for register, value in ((UC_X86_REG_CS, CODE), (UC_X86_REG_DS, CODE),
                                (UC_X86_REG_SS, STACK), (UC_X86_REG_SP, 0x1000),
                                (UC_X86_REG_SI, REQUEST)):
            machine.reg_write(register, value)
        calls = []

        def interrupt(cpu, number, _):
            self.assertEqual(number, 0x80)
            self.assertEqual(cpu.reg_read(UC_X86_REG_AX), 0x8101)
            calls.append(number)
            cpu.reg_write(UC_X86_REG_AX, firmware_status << 8 | 1)
            flags = cpu.reg_read(UC_X86_REG_EFLAGS)
            cpu.reg_write(UC_X86_REG_EFLAGS, (flags & ~1) | int(carry))

        machine.hook_add(UC_HOOK_INTR, interrupt)
        machine.emu_start(CODE * 16, CODE * 16 + STOP, count=200)
        self.assertEqual(calls, [0x80])
        self.assertEqual(machine.reg_read(UC_X86_REG_SP), 0x1004)
        return machine.reg_read(UC_X86_REG_AX), machine.reg_read(UC_X86_REG_CX)

    def test_success_reports_one_sector(self):
        self.assertEqual(self.execute(0, False), (0, 1024))

    def test_nonzero_status_survives_with_and_without_carry(self):
        for status in (2, 5, 0x17, 0xff):
            for carry in (False, True):
                with self.subTest(status=status, carry=carry):
                    self.assertEqual(self.execute(status, carry), (status, 0))

    def test_carry_without_status_is_unknown_not_success_or_write_protection(self):
        self.assertEqual(self.execute(0, True), (0xffff, 0))


if __name__ == "__main__":
    unittest.main()
