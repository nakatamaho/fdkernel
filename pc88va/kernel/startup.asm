; SPDX-License-Identifier: GPL-2.0-or-later
; Compile-only PC-88VA kernel entry. This code deliberately cannot continue.

bits 16

%ifdef NEC98
%error PC88VA and NEC98 selectors are mutually exclusive
%endif
%ifdef IBMPC
%error PC88VA and IBMPC selectors are mutually exclusive
%endif
%ifndef PC88VA
%error PC88VA selector is required
%endif

segment _TEXT class=CODE public use16

extern pc88va_platform_probe_
extern pc88va_console_diagnostic_
global ..start
global _pc88va_compile_only_entry
global _pc88va_compile_only_fatal_stop

..start:
_pc88va_compile_only_entry:
        cli
        cld
        call pc88va_platform_probe_
        call pc88va_console_diagnostic_

_pc88va_compile_only_fatal_stop:
        cli
        hlt
        jmp short _pc88va_compile_only_fatal_stop

segment _STACK class=STACK stack use16
        resb 256
