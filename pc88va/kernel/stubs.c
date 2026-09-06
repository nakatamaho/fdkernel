/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Fail-closed interfaces for the M06 PC-88VA compile-only kernel target. */

#if defined(NEC98) || defined(IBMPC)
#error PC88VA cannot be compiled with another machine-family selector
#endif
#ifndef PC88VA
#error PC88VA selector is required
#endif

typedef unsigned short pc88va_u16;

#define PC88VA_UNAVAILABLE (-1)

const char pc88va_platform_probe_marker[] =
  "M06STUB:PLATFORM_PROBE:FAIL_CLOSED";
const char pc88va_console_input_marker[] = "M06STUB:CONSOLE_INPUT:M11";
const char pc88va_nls_dbcs_marker[] = "M06STUB:NLS_DBCS:M17";

pc88va_u16 pc88va_platform_probe(void)
{
  return 0xffffu;
}

int pc88va_console_getc(pc88va_u16 *character)
{
  (void)character;
  return PC88VA_UNAVAILABLE;
}

int pc88va_nls_hook(void *request)
{
  (void)request;
  return PC88VA_UNAVAILABLE;
}
