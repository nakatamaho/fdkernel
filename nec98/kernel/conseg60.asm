; this is a part of FreeDOS(98) kernel
; included from console.asm or kernel.asm


%ifndef INCLUDE_CONSEG60

	[SECTION FAR_CON_TEXTSEG]

		extern	_text_vram_segment
		extern	_scroll_bottom
		extern	_cursor_view
		extern	_cursor_x
		extern	_cursor_y
		extern	_clear_char
		extern	_clear_attr
		extern	_put_attr
		extern	_scroll_bottom
		extern	_crt_line

	; switch back to previous section (to be safe)
	__SECT__

%else	; INCLUDE_CONSEG60


;--------------------------------------------------------------
; console
;--------------------------------------------------------------


; UBYTE  ASMCONPASCAL_FAR nec98_crt_set_mode_far(UBYTE mode)
; mode=0 25lines
;      1 20lines
; todo: support 30line (PC-9821)
		global	NEC98_CRT_SET_MODE_FAR
NEC98_CRT_SET_MODE_FAR:
		push	bp
		mov	bp, sp
arg_f mode
		mov	ah, 0bh			; sense CRT mode
		int	18h
		xor	ah, ah
		push	ax
		mov	ah, [.mode]
		and	ah, 01h
		and	al, 01eh
		or	al, ah
		mov	ah, 0ah			; set CRT mode
		int	18h
		mov	ah, 0ch			; CRT start displaying (text)
		int	18h
		pop	ax
		pop	bp
		retf	2


%ifndef INCLUDE_SUPSEG60

; VOID  ASMCON_FAR push_cursor_pos_to_conin(VOID);
;		global _push_cursor_pos_to_conin
_push_cursor_pos_to_conin:
		push	ds
		mov	ax, 0060h
		mov	ds, ax
		mov	word [0104h], _esc_seq_cursor_pos
		mov	byte [0103h], 8		; fixed length (^[yy;xxR)
		pop	ds
		retf

; VOID  ASMCON_FAR nec98_console_esc6n_far(VOID);
		global _nec98_console_esc6n_far
_nec98_console_esc6n_far:
		push	bx
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	bx, _esc_seq_cursor_pos + 2
		mov	dl, 10
		mov	al, [_cursor_y]
		call	.myatoi
		inc	bx
		mov	al, [_cursor_x]
		call	.myatoi
		mov	word [0104h], _esc_seq_cursor_pos
		mov	byte [0103h], 8		; fixed length (^[yy;xxR)
		pop	ds
		pop	bx
		retf
.myatoi:
		inc	al
		cmp	al, 99
		jbe	.ma_l02
		mov	al, 99
.ma_l02:
		mov	ah, 0
		div	dl
		call	.ma1
		mov	al, ah
.ma1:
		add	al, '0'
		mov	[bx], al
		inc	bx
		ret

%endif ;(ifndef INCLUDE_SUPSEG60)





; UBYTE  ASMCONPASCAL_FAR nec98_crt_rollup_far(UBYTE linecnt)
		global	NEC98_CRT_ROLLUP_FAR
NEC98_CRT_ROLLUP_FAR:
		push	bp
		mov	bp, sp
arg_f linecnt
		push	bx
		push	cx
		mov	dl, [.linecnt]
		call	nec98_crt_internal_roll_setupregs
		jc	.end
		call	nec98_crt_internal_rollup
	.end:
		pop	cx
		pop	bx
		pop	bp
		retf	2

; UBYTE  ASMCONPASCAL_FAR crt_rolldown(UBYTE linecnt)
		global	NEC98_CRT_ROLLDOWN_FAR
NEC98_CRT_ROLLDOWN_FAR:
		push	bp
		mov	bp, sp
arg_f linecnt
		push	bx
		push	cx
		mov	dl, [.linecnt]
		call	nec98_crt_internal_roll_setupregs
		jc	.end
		call	nec98_crt_internal_rolldown
	.end:
		pop	cx
		pop	bx
		pop	bp
		retf	2


nec98_crt_internal_roll_setupregs:
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	cl, [_cursor_y]
		mov	ch, [_scroll_bottom]
		mov	bh, byte [_clear_attr]
		mov	bl, byte [_clear_char]
		test	dl, dl
		jnz	.l2
		mov	dl, 1
	.l2:
		pop	ds
		cmp	ch, cl
		ret


; dl  scroll count
; cl  scroll area Y0 (0...row-1)
; ch  scroll area Y1 (0...row-1)
; bl  fill char
; bh  fill attr
;
; ax dx  break on return

nec98_crt_internal_rolldown:
		push	si
		push	di
		push	ds
		push	es
		mov	ax, 0060h
		mov	ds, ax
		mov	ax, [_text_vram_segment]
		mov	ds, ax
		mov	es, ax
		mov	dh, ch
		sub	dh, cl
		jb	.end
		cmp	dh, dl
		;jbe	.fill
		jae	.l2
		mov	dl, dh
		inc	dl
		jmp	short .fill
	.l2:
		std
		mov	al, 160
		push	ax
		inc	ch
		mul	ch
		dec	ch
		sub	ax, 2
		mov	di, ax
		pop	ax
		mul	dl
		mov	si, di
		sub	si, ax
		push	cx
		push	dx
		push	si
		push	di
		mov	al, 80
		inc	dh
		sub	dh, dl
		mul	dh
		mov	cx, ax
		rep	movsw
		pop	di
		pop	si
		add	di, 2000h
		add	si, 2000h
		mov	cx, ax
		rep	movsw
		pop	dx
		pop	cx
	.fill:
		cld
		push	cx
		mov	dh, ch
		sub	dh, dl
		inc	dh
		mov	al, 160
		mul	cl
		mov	di, ax
		mov	al, 80
		mul	dl
		mov	cx, ax
		push	cx
		push	di
		xor	ax, ax
		mov	al, bl
		rep	stosw
		pop	di
		pop	cx
		mov	al, bh
		mov	ah, bh
		add	di, 2000h
		rep	stosw
		pop	cx
	.end:
		pop	es
		pop	ds
		pop	di
		pop	si
		ret


nec98_crt_internal_rollup:
		push	si
		push	di
		push	ds
		push	es
		mov	ax, 0060h
		mov	ds, ax
		mov	ax, [_text_vram_segment]
		mov	ds, ax
		mov	es, ax
		cld
		mov	dh, ch
		sub	dh, cl
		jb	.end
		cmp	dh, dl
		;jbe	.fill
		jae	.l2
		mov	dl, dh
		inc	dl
		jmp	short .fill
	.l2:
		mov	al, 160
		push	ax
		mul	cl
		mov	di, ax
		pop	ax
		mul	dl
		mov	si, di
		add	si, ax
		push	cx
		push	dx
		push	si
		push	di
		mov	al, 80
		inc	dh
		sub	dh, dl
		mul	dh
		mov	cx, ax
		rep	movsw
		pop	di
		pop	si
		add	di, 2000h
		add	si, 2000h
		mov	cx, ax
		rep	movsw
		pop	dx
		pop	cx
	.fill:
		push	cx
		mov	dh, ch
		sub	dh, dl
		inc	dh
		mov	al, 160
		mul	dh
		mov	di, ax
		mov	al, 80
		mul	dl
		mov	cx, ax
		push	cx
		push	di
		xor	ax, ax
		mov	al, bl
		rep	stosw
		pop	di
		pop	cx
		mov	al, bh
		mov	ah, bh
		add	di, 2000h
		rep	stosw
		pop	cx
	.end:
		pop	es
		pop	ds
		pop	di
		pop	si
		ret

; VOID  ASMCCN_FAR nec98_crt_scroll_up_far(VOID)
		global	_nec98_crt_scroll_up_far
_nec98_crt_scroll_up_far:
		push	bx
		push	cx
		call	nec98_crt_internal_roll_setupregs
		mov	cl, 0
		mov	dl, 1
		call	nec98_crt_internal_rollup
		pop	cx
		pop	bx
		retf


; VOID ASMCON_FAR  nec98_clear_crt_all_far(VOID)
		global	_nec98_clear_crt_all_far
_nec98_clear_crt_all_far:
		cld
		push	cx
		push	di
		push	ds
		push	es

		mov	ax, 60h
		mov	ds, ax
		mov	dl, [_clear_char]
		mov	dh, [_clear_attr]
		mov	es, [_text_vram_segment]

		xor	di, di
		mov	cx, 1000h / 2
		xor	ah, ah
		mov	al, dl
		rep	stosw

		mov	di, 2000h
		mov	cx, 1000h / 2
		xor	ah, ah
		mov	al, dh
		rep	stosw

		pop	es
		pop	ds
		pop	di
		pop	cx
		retf


%ifdef USE_PUTCRT_SEG60

; internal
; input:
; dl = X, dh = Y
; (if dx==-1, cursor position is not update)
; result:
; dx = new cursor addr in text-vram
nec98_update_curpos_noseg:
		cmp	dx, 0ffffh
		je	.update
		mov	[_cursor_x], dl
		mov	[_cursor_y], dh
.update:
		cmp	byte [_cursor_view], 0
		je	.exit
		mov	al, 80
		mul	byte [_cursor_y]
		add	al, [_cursor_x]
		adc	ah, 0
		add	ax, ax
		mov	dx, ax
		mov	ah, 13h		; locate cursor position
		int	18h
.exit:
		ret

nec98_update_curpos:
		push	ax
		push	ds
		mov	ax, 60h
		mov	ds, ax
		call	nec98_update_curpos_noseg
		pop	ds
		pop	ax
		ret

; VOID  ASMCONPASCAL_FAR nec98_set_curpos_far(UBYTE posx, UBYTE posy)
		global	NEC98_SET_CURPOS_FAR
NEC98_SET_CURPOS_FAR:
		push	bp
		mov	bp, sp
arg_f posx, posy
		push	dx
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	dl, [.posx]
		mov	dh, [.posy]
		call	nec98_update_curpos_noseg
		mov	ax, dx
		pop	ds
		pop	dx
		pop	bp
		retf	4


nec98_show_hide_cursor:
		push	dx
		push	ds
		mov	dx, 60h
		mov	ds, dx
		cmp	ax, -1
		jnz	.l1
		mov	al, [_cursor_view]	; do not modified if ax==ffffh
.l1:
		test	al, al
		jnz	.show
		mov	[_cursor_view], al
		mov	ah, 12h
		int	18h
		jmp	short .exit
.show:
		mov	al, 1
		mov	[_cursor_view], al
		push	ax
		mov	ah, 11h
		int	18h
		mov	dx, -1
		call	nec98_update_curpos_noseg
		pop	ax
.exit:
		pop	ds
		pop	dx
		ret

; UWORD  ASMCONPASCAL_FAR nec98_show_hide_cursor_far(UBYTE showhide)
		global	NEC98_SHOW_HIDE_CURSOR_FAR
NEC98_SHOW_HIDE_CURSOR_FAR:
		push	bp
		mov	bp, sp
arg_f showhide
		mov	ax, [.showhide]
		call	nec98_show_hide_cursor
		pop	bp
		retf	2

; UWORD  ASMCONPASCAL_FAR nec98_update_cursor_view_far(VOID)
		global	NEC98_UPDATE_CURSOR_VIEW_FAR
NEC98_UPDATE_CURSOR_VIEW_FAR:
		mov	ax, -1
		call	nec98_show_hide_cursor
		retf

nec98_get_width:
		push	ds
		xor	ax, ax
		mov	ds, ax
		mov	al, [053ch]	; CRT_STS_FLAG
		test	al, 2		; bit1: 0=80cols 1=40cols
		mov	al, 80
		jz	.exit
		mov	al, 40
.exit:
		pop	ds
		ret


; internal
; input:
; dl = X, dh = Y, ds=60h
; result
; di:vram addr
nec98_xy_to_addr:
		push	ax
		push	dx
		mov	al, 80		; columns
		mul	dh
		mov	dh, 0
		add	ax, dx
		shl	ax, 1
		mov	di, ax
		pop	dx
		pop	ax
		ret

; internal
; input:
; ax = code, dl = X, dh = Y, cx=attr, flags:DF=0, ds=60h
; result:
; ax:broken
nec98_putcrta_noseg:
		push	di
		push	es
		mov	es, [_text_vram_segment]
		call	nec98_xy_to_addr
		stosw
		add	di, 1ffeh
		mov	ax, cx
		stosw
		pop	es
		pop	di
		ret

; VOID ASMCONPASCAL_FAR  nec98_put_crt_far(UBYTE x, UBYTE y, UWORD ccode)
		global	NEC98_PUT_CRT_FAR
NEC98_PUT_CRT_FAR:
		push	bp
		mov	bp, sp
arg_f posx, posy, ccode
		push	cx
		push	dx
		push	ds
		mov	cx, 60h
		mov	ds, cx
		mov	cl, [_put_attr]
		mov	dl, [.posx]
		mov	dh, [.posy]
		mov	ax, [.ccode]
		call	nec98_putcrta_noseg
		pop	ds
		pop	dx
		pop	cx
		pop	bp
		retf	6

; VOID ASMCONPASCAL_FAR  nec98_put_crt_wattr_far(UBYTE x, UBYTE y, UWORD ccode, UWORD attr)
		global	NEC98_PUT_CRT_WATTR_FAR
NEC98_PUT_CRT_WATTR_FAR:
		push	bp
		mov	bp, sp
arg_f posx, posy, ccode, attr
		push	cx
		push	dx
		push	ds
		mov	cx, 60h
		mov	ds, cx
		mov	cl, [_put_attr]
		mov	dl, [.posx]
		mov	dh, [.posy]
		mov	ax, [.ccode]
		or	cx, [.attr]
		call	nec98_putcrta_noseg
		pop	ds
		pop	dx
		pop	cx
		pop	bp
		retf	8

;
nec98_crt_internal_clear_1:
		mov	cx, 1
nec98_crt_internal_clear_n:
		jcxz	.exit
		push	dx
		push	di
		push	ds
		push	es
		mov	ax, 60h
		mov	ds, ax
		call	nec98_xy_to_addr
		mov	es, [_text_vram_segment]
		xor	ah, ah
		mov	al, [_clear_char]
		push	cx
		push	di
		rep	stosw		; (40cols mode not supported for now)
		pop	di
		pop	cx
		add	di, 2000h
		mov	al, [_clear_attr]
		rep	stosw
		pop	es
		pop	ds
		pop	di
		pop	dx
.exit:
		ret

; VOID ASMCONPASCAL_FAR  nec98_clear_crt_n_far(UBYTE posx, UBYTE posy, UWORD count);
NEC98_CLEAR_CRT_N_FAR:
		cld
		push	bp
		mov	bp, sp
arg_f posx, posy, count
		push	cx
		push	dx
		mov	dl, [.posx]
		mov	dh, [.posy]
		mov	cx, [.count]
		call	nec98_crt_internal_clear_n
		pop	dx
		pop	cx
		pop	bp
		retf	6

; VOID ASMCONPASCAL_FAR  nec98_clear_crt_far(UBYTE x, UBYTE y)
		global	NEC98_CLEAR_CRT_FAR
NEC98_CLEAR_CRT_FAR:
		push	bp
		mov	bp, sp
arg_f posx, posy
		push	cx
		push	dx
		mov	dl, [.posx]
		mov	dh, [.posy]
		call	nec98_crt_internal_clear_1
		pop	dx
		pop	cx
		pop	bp
		retf	4

;
%if 0		; comment
STATIC UWORD sjis2jis(UWORD c)
{
  UBYTE h = c >> 8;
  UBYTE l = c;

  if(h <= 0x9f)
  {
    h <<= 1;
    if(l < 0x9f)
      h -= 0xe1;
    else
      h -= 0xe0;
  }
  else
  {
    h <<= 1;
    if(l < 0x9f)
      h -= 0x161;
    else
      h -= 0x160;
  }
  if(l <= 0x7f)
    l -= 0x1f;
  else if(l < 0x9f)
    l -= 0x20;
  else
    l -= 0x7e;

  return ((UWORD)h << 8) | l;
}
%endif		; endcomment
con_sjis2jis:
		cmp	ah, 9fh
		ja	.h_a0
		shl	ah, 1
		cmp	al, 9fh
		jae	.h_9f_l_9f
		sub	ah, 0e1h
		jmp	short .l
.h_9f_l_9f:
		sub	ah, 0e0h
		jmp	short .l
.h_a0:
		shl	ah, 1
		cmp	al, 9fh
		jae	.h_a0_l_9f
		sub	ah, 61h
		jmp	short .l
.h_a0_l_9f:
		sub	ah, 60h
.l:
		cmp	al, 7fh
		ja	.l_80
		sub	al, 1fh
		jmp	short .hl
.l_80:
		cmp	al, 9fh
		jae	.l_9f
		sub	al, 20h
		jmp	short .hl
.l_9f:
		sub	al, 7eh
.hl:
		ret

; UWORD  ASMCONPASCAL_FAR nec98_sjis2jis_far(UWORD sjis)
		global	NEC98_SJIS2JIS_FAR
NEC98_SJIS2JIS_FAR:
		push	bp
		mov	bp, sp
arg_f sjis
		mov	ax, [.sjis]
		call	con_sjis2jis
		pop	bp
		retf	2

%endif ; USE_PUTCRT_SEG60

%ifdef INCLUDE_CONKEY60
; internal
; input:
; ax = index, dl = X, dh = Y, flags:DF=0, ds=60h
; result:
; ax,bx,cx,dx,es:broken
nec98_crt_internal_putfunc:
		push	dx
		call	nec98_fetch_key_table	; es:bx=key, cx=length
		cmp	cx, 6
		jbe	.fixed_cx
		mov	cx, 6
.fixed_cx:
		pop	dx
		xor	si, si
		xchg	si, bx			; bx=0, (es:)si=key
		call	nec98_xy_to_addr
		mov	es, [_text_vram_segment]
; clear grid
		push	cx
		push	di
		mov	cx, 6
		mov	al, [_clear_attr]
		xor	al, 4
		xor	ah, ah
		mov	dx, ax
.lp_pre_clr:
		mov	al, ' '		; space (not clear_char)
		stosw
		mov	al, dl
		mov	[es: di + 1ffeh], dx
		loop	.lp_pre_clr
		pop	di
		pop	cx
		jcxz	.lp_brk
;.lp_0
		lodsb
		cmp	al, 0feh	; check 1st FEh (will be always space)
		jne	.lp_m1
		xor	ah, ah
		mov	al, ' '
		jmp	short .lp_m1
.lp:
		cmp	bx, cx
		jae	.lp_brk
		lodsb
.lp_m1:
		xor	ah, ah
		cmp	ah, [008ah]	; GRAPH mode?
		je	.lp_s
		cmp	al, 81h
		jb	.lp_s
		cmp	al, 9fh
		jbe	.lp_d
		cmp	al, 0e0h
		jb	.lp_s
		cmp	al, 0fch
		ja	.lp_s
.lp_d:
		inc	bx
		cmp	bx, cx
		jb	.lp_d_2
		mov	al, ' '
		jmp	short .lp_s
.lp_d_2:
		mov	ah, al
		lodsb
		call	con_sjis2jis
		sub	ax, 2000h
		xchg	al, ah
		stosw
		or	al, 80h
.lp_s:
		stosw
		inc	bx
		jmp	short .lp
.lp_brk:
		ret

nec98_crt_clrfuncline:
		mov	ax, 0060h
		mov	ds, ax
		xor	dl, dl
		mov	dh, [_scroll_bottom]
		inc	dh
		mov	cx, 80
		call	nec98_crt_internal_clear_n
		ret

nec98_crt_putfuncline:
		call	nec98_crt_clrfuncline	; and setup dx, ds, es
		mov	dl, 1
		xor	ch, ch
		mov	cl, [_put_attr]
		xor	ah, ah
		mov	al, [_kanjigraph_char]
		call	nec98_putcrta_noseg
		inc	dl
		xor	ah, ah
		mov	al, [_shiftfunc_char]
		call	nec98_putcrta_noseg
		mov	al, 1
		cmp	al, byte [_function_flag]
		je	.l1
		add	al, 10
.l1:
		mov	dl, 4
		call	.disp_onegrid
		mov	dl, 4 + 7*5 + 3
.disp_onegrid:
		mov	cx, 5
.lp:
		push	ax
		push	cx
		push	dx
		call	nec98_crt_internal_putfunc
		pop	dx
		pop	cx
		pop	ax
		add	dl, 7
		inc	ax
		loop	.lp
		ret

  %ifndef INCLUDE_SUPSEG60

; VOID ASMCONPASCAL_FAR nec98_put_func_index_far(UBYTE x, UBYTE y, UWORD index);
		global NEC98_PUT_FUNC_INDEX_FAR
NEC98_PUT_FUNC_INDEX_FAR:
		push	bp
		mov	bp, sp
arg_f posx, posy, index
		push	bx
		push	cx
		push	si
		push	di
		push	ds
		push	es
		mov	ax, 60h
		mov	ds, ax
		mov	dl, [.posx]
		mov	dh, [.posy]
		mov	ax, [.index]
		call	nec98_crt_internal_putfunc
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	cx
		pop	bx
		pop	bp
		retf	6

; VOID  ASMCON_FAR nec98_put_funcs_far(VOID);
		global _nec98_put_funcs_far
_nec98_put_funcs_far:
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es
		cld
		call	nec98_crt_putfuncline
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		retf

; VOID  ASMCON_FAR nec98_clear_funcs_far(VOID);
		global _nec98_clear_funcs_far
_nec98_clear_funcs_far:
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es
		cld
		call	nec98_crt_clrfuncline
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		retf

  %endif ; (ifndef INCLUDE_SUPSEG60)


; ax = code, dl = X, dh = Y, cx=attr, flags:DF=0, ds=60h


%endif		; INCLUDE_CONKEY60

%endif		; INCLUDE_CONSEG60
