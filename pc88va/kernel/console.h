/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef PC88VA_CONSOLE_H
#define PC88VA_CONSOLE_H

/* M09 early output only; AX input/result under the Watcom register ABI. */
int pc88va_console_putc(unsigned short character);

#endif
