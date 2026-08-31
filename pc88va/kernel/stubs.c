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
const char pc88va_machine_init_marker[] = "M06STUB:MACHINE_INIT:M10";
const char pc88va_disk_read_marker[] = "M06STUB:DISK_READ:M08";
const char pc88va_console_output_marker[] = "M06STUB:CONSOLE_OUTPUT:M09";
const char pc88va_console_input_marker[] = "M06STUB:CONSOLE_INPUT:M11";
const char pc88va_timer_clock_marker[] = "M06STUB:TIMER_CLOCK:M10";
const char pc88va_interrupts_marker[] = "M06STUB:INTERRUPTS:M10";
const char pc88va_memory_marker[] = "M06STUB:MEMORY:M10";
const char pc88va_fatal_stop_marker[] = "M06STUB:FATAL_STOP:M10";
const char pc88va_loader_handoff_marker[] = "M06STUB:LOADER_HANDOFF:M08";
const char pc88va_nls_dbcs_marker[] = "M06STUB:NLS_DBCS:M17";

pc88va_u16 pc88va_platform_probe(void)
{
  return 0xffffu;
}

int pc88va_machine_init(void)
{
  return PC88VA_UNAVAILABLE;
}

int pc88va_disk_read(void *request)
{
  (void)request;
  return PC88VA_UNAVAILABLE;
}

int pc88va_console_putc(pc88va_u16 character)
{
  (void)character;
  return PC88VA_UNAVAILABLE;
}

int pc88va_console_getc(pc88va_u16 *character)
{
  (void)character;
  return PC88VA_UNAVAILABLE;
}

int pc88va_clock_read(void *record)
{
  (void)record;
  return PC88VA_UNAVAILABLE;
}

int pc88va_interrupts_init(void)
{
  return PC88VA_UNAVAILABLE;
}

int pc88va_memory_query(void *record)
{
  (void)record;
  return PC88VA_UNAVAILABLE;
}

int pc88va_fatal_stop_request(pc88va_u16 reason)
{
  (void)reason;
  return PC88VA_UNAVAILABLE;
}

int pc88va_loader_handoff(void *record)
{
  (void)record;
  return PC88VA_UNAVAILABLE;
}

int pc88va_nls_hook(void *request)
{
  (void)request;
  return PC88VA_UNAVAILABLE;
}
