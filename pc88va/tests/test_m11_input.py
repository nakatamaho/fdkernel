#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Synthetic BIOS instruction tests, explicitly not private qualification."""
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_MEM_WRITE
from unicorn.x86_const import *

TARGET = Path(__file__).resolve().parents[1]
CODE, STACK, STOP = 0x1000, 0x7000, 0x3f00

class InputTests(unittest.TestCase):
    def execute(self, sequence, *, ready=2, pointer=True, vector=True,
                ds=CODE, flags=0x93, clobber=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, binary = root/'test.asm', root/'test.bin'
            source.write_text('bits 16\ncpu 8086\norg 0\njmp near pc88va_console_getc_\n'
                              'dw pc88va_m11_character_\n'
                              f'pc88va_m10_state_: db {ready}\n'
                              '%define M11_FLAT_TEST 1\n%include "console_input.asm"\n')
            subprocess.run(['nasm', '-f', 'bin', '-DPC88VA', '-I', str(TARGET/'kernel')+'/',
                            '-o', str(binary), str(source)], check=True, capture_output=True)
            code = binary.read_bytes()
        output = struct.unpack_from('<H', code, 3)[0]
        cpu = Uc(UC_ARCH_X86, UC_MODE_16)
        cpu.mem_map(0, 0x100000)
        cpu.mem_write(CODE*16, code)
        cpu.mem_write(CODE*16+output, b'\xad\xde')
        if vector: cpu.mem_write(0x82*4, struct.pack('<HH', 0x100, 0x8000))
        regs = {UC_X86_REG_BX: 0x1357, UC_X86_REG_CX: 0x2468,
                UC_X86_REG_DX: 0x4567, UC_X86_REG_SI: 0x3456,
                UC_X86_REG_DI: 0x5678, UC_X86_REG_BP: 0x6789,
                UC_X86_REG_DS: ds, UC_X86_REG_ES: 0x4000,
                UC_X86_REG_SS: STACK, UC_X86_REG_EFLAGS: flags}
        calls, writes, results = [], [], []
        current = [None]
        def interrupt(machine, number, _):
            self.assertEqual(number, 0x82, 'no echo or unrelated BIOS')
            fn = machine.reg_read(UC_X86_REG_AH)
            calls.append(fn)
            self.assertIn(fn, (0x0a, 0x09))
            if clobber:
                for reg in regs:
                    if reg not in (UC_X86_REG_SS, UC_X86_REG_EFLAGS):
                        machine.reg_write(reg, 0xaaaa)
            if fn == 0x0a:
                machine.reg_write(UC_X86_REG_EFLAGS, 0x46 | (current[0] is None))
            else:
                self.assertIsNotNone(current[0])
                machine.reg_write(UC_X86_REG_AX, current[0])
        cpu.hook_add(UC_HOOK_INTR, interrupt)
        cpu.hook_add(UC_HOOK_MEM_WRITE, lambda uc, access, address, size, value, data:
                     writes.append((address, size)))
        for item in sequence:
            current[0] = item
            for reg, value in regs.items(): cpu.reg_write(reg, value)
            cpu.reg_write(UC_X86_REG_CS, CODE)
            cpu.reg_write(UC_X86_REG_SP, 0x1000)
            cpu.reg_write(UC_X86_REG_AX, output if pointer else 0)
            cpu.mem_write(STACK*16+0x1000, struct.pack('<H', STOP))
            cpu.emu_start(CODE*16, CODE*16+STOP, count=5000)
            self.assertEqual(cpu.reg_read(UC_X86_REG_IP), STOP)
            self.assertEqual(cpu.reg_read(UC_X86_REG_SP), 0x1002)
            for reg, value in regs.items(): self.assertEqual(cpu.reg_read(reg), value)
            results.append((cpu.reg_read(UC_X86_REG_AX),
                            struct.unpack('<H', cpu.mem_read(CODE*16+output, 2))[0]))
        self.assertTrue(all((STACK*16+0xfee <= a and a+n <= STACK*16+0x1000) or
                            (a == CODE*16+output and n == 2) for a,n in writes))
        return results, calls

    def test_supported(self):
        chars = [8, 13] + list(range(0x20, 0x7f))
        self.assertEqual(self.execute(chars, clobber=True)[0], [(0,c) for c in chars])

    def test_empty_delayed_repeated(self):
        self.assertEqual(self.execute([None, None, ord('a'), None, ord('a'), None])[0],
                         [(1,0xdead), (1,0xdead), (0,97), (1,97), (0,97), (1,97)])

    def test_unsupported_no_stale_success(self):
        chars = [x for x in range(256) if x not in [8,13] and not 0x20 <= x <= 0x7e]
        self.assertEqual(self.execute(chars)[0], [(2,0xdead)] * len(chars))

    def test_preconditions(self):
        for options in ({'ready':0}, {'ready':1}, {'ready':3}, {'pointer':False},
                        {'vector':False}, {'ds':0x3000}, {'flags':0x202}, {'flags':0x402}):
            with self.subTest(options=options):
                self.assertEqual(self.execute([65], **options), ([(0xffff,0xdead)], []))

if __name__ == '__main__': unittest.main()
