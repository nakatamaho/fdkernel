#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Structural tests for the compile-only PC-88VA target."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "pc88va"


class TargetTests(unittest.TestCase):
    def test_independent_selector(self) -> None:
        makefile = (TARGET / "makefile.wc").read_text(encoding="utf-8")
        self.assertIn("-DPC88VA", makefile)
        self.assertNotIn("-DNEC98", makefile)
        self.assertNotIn("-DIBMPC", makefile)

    def test_machine_selectors_are_mutually_exclusive(self) -> None:
        for relative in ("kernel/startup.asm", "kernel/stubs.c"):
            text = (TARGET / relative).read_text(encoding="utf-8")
            self.assertIn("NEC98", text)
            self.assertIn("IBMPC", text)
            self.assertIn("PC88VA", text)

    def test_link_inputs_are_explicit_and_not_nec98(self) -> None:
        lines = (TARGET / "config/link.rsp").read_text(encoding="ascii").splitlines()
        self.assertEqual(lines.count("file build/startup.obj"), 1)
        self.assertEqual(lines.count("library build/platform.lib"), 1)
        self.assertFalse(any("nec98" in line.lower() or "ibmpc" in line.lower() for line in lines))

    def test_object_plan_has_closed_classifications(self) -> None:
        plan = json.loads((TARGET / "config/build-plan.json").read_text(encoding="utf-8"))
        allowed = {"common-core", "shared-portable", "pc88va-owned", "temporary-fail-closed-stub"}
        self.assertTrue(plan["objects"])
        self.assertTrue(all(item["classification"] in allowed for item in plan["objects"]))
        self.assertFalse(any("/nec98/" in item["source"] or "/ibmpc/" in item["source"] for item in plan["objects"]))

    def test_stub_ledger_matches_source_and_fails_closed(self) -> None:
        ledger = json.loads((TARGET / "config/stubs.json").read_text(encoding="utf-8"))
        source = (TARGET / "kernel/stubs.c").read_text(encoding="utf-8")
        self.assertEqual(ledger["failure_return"], -1)
        self.assertEqual(len(ledger["interfaces"]), 10)
        for item in ledger["interfaces"]:
            self.assertRegex(item["removal_milestone"], r"^M(?:0[789]|1[0-7])$")
            self.assertIn(item["name"], source)
            self.assertIn(item["marker"], source)
        self.assertGreaterEqual(source.count("return PC88VA_UNAVAILABLE;"), 10)

    def test_stubs_have_no_hardware_access(self) -> None:
        text = (TARGET / "kernel/stubs.c").read_text(encoding="utf-8").lower()
        forbidden = ("__int__", " out ", " in ", "outp(", "inp(", "asm", "firmware")
        self.assertFalse(any(token in text for token in forbidden))

    def test_no_ambient_time_macros(self) -> None:
        for path in sorted(TARGET.rglob("*")):
            if path.is_file() and path.suffix.lower() in {".c", ".h", ".asm", ".wc", ".rsp"}:
                text = path.read_text(encoding="utf-8")
                self.assertIsNone(re.search(r"__(?:DATE|TIME|TIMESTAMP)__", text))


if __name__ == "__main__":
    unittest.main()
