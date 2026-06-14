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

		extern	_crt_is_hires
		extern	_crt_is_98gs
		extern	_crt_has_mode21
		extern	_crt_mode_org
		extern	_crt_m9821_al_org
		extern	_crt_m9821_bh_org

	; switch back to previous section (to be safe)
	__SECT__

%else	; INCLUDE_CONSEG60


;--------------------------------------------------------------
; console
;--------------------------------------------------------------

		global	_crt_is_hires
		global	_crt_is_98gs
		global	_crt_has_mode21
		global	_crt_mode_org
		global	_crt_m9821_al_org
		global	_crt_m9821_bh_org
_crt_mode_org		db	0	; int18h ah=0Bh
_crt_is_hires		db	0	; 0000:0501 bit3 (and bit5 if bit3=1)
_crt_has_mode21		db	0	;
_crt_is_98gs		db	0
_crt_m9821_al_org	db	0	; int1Bh ah=31h (AL and 0Fh)
_crt_m9821_bh_org	db	0	;               (BH and 33h)


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


; internal
; input:
; dl = X, dh = Y
; (if dx==-1, cursor position is not update)
; result:
; dx = new cursor addr in text-vram
nec98_update_curposdisp_noseg:
		mov	ah, 11h
		cmp	byte [_cursor_view], 0
		jne	.l2
		mov	ah, 12h
.l2:
		int	18h
nec98_update_curpos_noseg:
		cmp	dx, 0ffffh
		je	.update
		mov	[_cursor_x], dl
		mov	[_cursor_y], dh
.update:
		mov	dl, [_cursor_x]
		mov	dh, [_cursor_y]
		cmp	byte [_cursor_view], 0
		je	.exit
		mov	al, 80
		mul	dh
		add	al, dl
		adc	ah, 0
		add	ax, ax
		push	dx
		mov	dx, ax
		mov	ah, 13h		; locate cursor position
		int	18h
		pop	dx
.exit:
		ret

; internal
; input:
; dl = X, dh = Y
; ah = offset
; result:
; dl = clipped X
; dh = clipped Y
nec98_clip_curpos_noseg:
		push	ax
		mov	al, 79
		sub	dl, ah
		jnc	.l_x1
		mov	dl, 0
.l_x1:
		cmp	dl, al
		jbe	.l_y0
		mov	dl, al
.l_y0:
		mov	al, [_scroll_bottom]
		sub	dh, ah
		jnc	.l_y1
		mov	dh, 0
.l_y1:
		cmp	dh, al
		jbe	.l_exit
		mov	dh, al
.l_exit:
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
		call	nec98_clip_curpos_noseg		; ah = 0
		call	nec98_update_curpos_noseg
		mov	ax, dx
		pop	ds
		pop	dx
		pop	bp
		retf	4

; VOID  ASMCONPASCAL_FAR nec98_set_curpos_clipped_far(UBYTE posx, UBYTE posy, UBYTE ofs)
		global	NEC98_SET_CURPOS_CLIPPED_FAR
NEC98_SET_CURPOS_CLIPPED_FAR:
		push	bp
		mov	bp, sp
arg_f posx, posy, ofs
		push	dx
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	dl, [.posx]
		mov	dh, [.posy]
		mov	ah, [.ofs]
		call	nec98_clip_curpos_noseg
		call	nec98_update_curpos_noseg
		mov	ax, dx
		pop	ds
		pop	dx
		pop	bp
		retf	6

;
; input
; ds 60h
; al direction: 0 up, 1 down, 2 right, 3 left
; dl, dh current pos (x,y)
; cl move count (unsigned)
;
; output
; dl, dh updated pos (x,y)
; ah broken
nec98_move_curpos_rel_sub:
		cmp	al, 3
		je	.left
		cmp	al, 2
		je	.right
		cmp	al, 1
		je	.down
		cmp	al, 0
		je	.up
		ret
.left:
		sub	dl, cl
		jnc	.l_exit
		xor	dl, dl		; clip (0, y)
.l_exit:
		ret
.right:
		mov	ah, 79		; cols - 1
		add	dl, cl
		jc	.r_clip
		cmp	dl, ah
		jbe	.r_exit
.r_clip:
		mov	dl, ah		; clip (cols-1, y)
.r_exit:
		ret
.up:
		sub	dh, cl
		jnc	.u_exit
		xor	dh, dh		; clip (x, 0)
.u_exit:
		ret
.down:
		mov	ah, [_scroll_bottom]
		add	dh, cl
		jc	.d_clip
		cmp	dh, ah
		jbe	.d_exit
.d_clip:
		mov	dh, ah		; clip (x, rows-1)
.d_exit:
		ret

;
; input
; ds 60h
; al direction: 0 up, 1 down, 2 right, 3 left
; dl, dh current pos (x,y)
; cl move count (unsigned)
;
; output
; dl, dh updated pos (x,y)
; ah broken
; cx clipped to 00FFh if cx >= 0100h
nec98_move_curpos_rel_noseg:
		test	ch, ch
		jz	.l0
		mov	cx, 00ffh
.l0:
		mov	dl, [_cursor_x]
		mov	dh, [_cursor_y]
		call	nec98_move_curpos_rel_sub
		call	nec98_update_curpos_noseg
		ret

; VOID ASMCONPASCAL_FAR nec98_move_curpos_rel_far(UBYTE direction, UWORD count)
		global	NEC98_MOVE_CURPOS_REL_FAR
NEC98_MOVE_CURPOS_REL_FAR:
		push	bp
		mov	bp, sp
arg_f direction, count
		push	bx
		push	cx
		push	dx
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	al, [.direction]
		mov	cx, [.count]
		call	nec98_move_curpos_rel_noseg
		pop	ds
		pop	dx
		pop	cx
		pop	bx
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


;
; input
; al = 0 20lines
;      1 25lines
;      2 30lines (9821)
;     others no operation
; return
; cf=0 success
; ah=screen rows (20, 25, 30)
; cf=1 failure (no change)
; ah=0

%define WORKAROUND_FOR_NP21	1
%ifndef WORKAROUND_FOR_NP21
  %define WORKAROUND_FOR_NP21	0
%endif

nec98_crt_moden:
		cmp	byte [_crt_has_mode21], 0
		je	.n0
		cmp	al, 2
		ja	.err
		push	bx
		mov	bx, [_crt_m9821_al_org]		; restore scanlines and hsync
		and	bh, 30h
		cmp	al, 2
		jne	.n21_chk25
%if WORKAROUND_FOR_NP21
		; turn into 25lines mode if 20lines
		push	ax
		mov	ah, 0bh
		int	18h
		test	al, 10h
		jnz	.n21_np21e
		test	al, 01h
		jz	.n21_np21e
		and	al, 0eh
		mov	ah, 0ah
		int	18h
.n21_np21e:
		pop	ax
%endif
		mov	ah, 30
		or	bx, 320ch
		jmp	short .n21_set
.n21_chk25:
		cmp	al, 1
		jne	.n21_chk20
		mov	ah, 25
		or	bh, 1
		jmp	short .n21_set
.n21_chk20:
;		cmp	al, 0
;		jne	.n21_3
		mov	ah, 20
		;and	bh, 30h
.n21_set:
		push	ax
		mov	al, bl
		mov	ah, 30h
		int	18h
		add	bh, 0ffh
		jc	.n21_after
		mov	ah, 0ch			; CRT start displaying (text)
		int	18h
		clc
.n21_after:
		pop	ax
		pop	bx
		jc	.err
%if WORKAROUND_FOR_NP21
		cmp	al, 1			; fallthrough to 9801 routine if 20/25lines (workaound for np21)
		jbe	.n0
%endif
		ret
.err:
		xor	ah, ah
		stc
		ret
.n0:
		cmp	al, 2
		jae	.err
		push	bx
		xchg	ax, bx
		mov	ah, 0bh
		int	18h
		and	al, 0eh
		mov	bh, 25
		test	bl, bl
		jnz	.n0_set
		or	al, 1
		mov	bh, 20
.n0_set:
		mov	ah, 0ah
		int	18h
		mov	ah, 0ch			; CRT start displaying (text)
		int	18h
		xchg	ax, bx
		pop	bx
		clc
		ret

;
; input
; al = 0 25lines
;      1 31lines
;     others no operation
; return
; cf=0 success
; ah=screen rows (25, 31)
; cf=1 failure (no change)
; ah=0

nec98_crt_modeh:
		cmp	al, 1
		jbe	.h0
.err:
		xor	ah, ah
		stc
		ret
.h0:
		mov	ah, 25
		jne	.h1
		mov	ah, 31
.h1:
		push	ax
		push	bx
		xchg	ax, bx
		mov	ah, 0bh
		int	18h
		and	al, 0fh		; 25lines (bit4=0)
		test	bl, bl
		jz	.h_set
		or	al, 10h		; 31lines (bit4=1)
.h_set:
		mov	ah, 0ah
		int	18h
		mov	ah, 0ch
		int	18h
		pop	bx
		pop	ax
		clc
		ret

;
; input
; ds   60h
; al = 'l' 20lines (normal)
;      'n' 25lines (normal/hires)
;      'h' 30lines (normal) / 31lines (hires)
; result
; cf=0 success
; ah   screen rows
; al   0 20lines(normal) / 25lines(hires)
;      1 25lines(normal) / 31lines(hires)
;      2 30lines(normal PC9821)
;
; cf=1 failure
; ah   0 
nec98_crt_modenh:
		test	byte [_crt_is_hires], 8
		jnz	.h0
		mov	ah, 2
		cmp	al, 'n'
		je	.n1
		mov	ah, 1
		cmp	al, 'l'
		je	.n1
		mov	ah, 0
		cmp	al, 'h'
		je	.n1
.nh_err:
		stc
.nh_exit:
		ret
.h0:
		mov	ah, 1
		cmp	al, 'n'
		je	.h1
		mov	ah, 0
		cmp	al, 'l'
		je	.h1
		jmp	short .nh_err
.h1:
		mov	al, ah
		call	nec98_crt_modeh
		jc	.nh_exit
		jmp	short .nhc
.n1:
		mov	al, ah
		call	nec98_crt_moden
		jc	.nh_exit
.nhc:
%if 0
		cmp	al, 1
		ja	.nhc_1
		mov	al, 1
.nhc_1:
%endif
		mov	[_crt_line], al
		mov	al, [_function_flag]
		cmp	al, 0
		je	.nhc_2
		mov	al, 1
		dec	ah
		mov	byte [_shiftfunc_char], ' '
.nhc_2:
		dec	ah
		mov	[_function_flag], al
		mov	[_scroll_bottom], ah
		mov	ax, 324ah		; '2J'
		call	nec_98_crt_escjk_nosegdx
		ret

; VOID ASMCONPASCAL_FAR nec98_crt_setmodenh_far(UBYTE hln)
		global NEC98_CRT_SETMODENH_FAR
NEC98_CRT_SETMODENH_FAR:
		push	bp
		mov	bp, sp
arg_f hln
		push	cx
		push	dx
		push	ds
		push	es
		mov	ax, 60h
		mov	ds, ax
		mov	al, [.hln]
		call	nec98_crt_modenh
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bp
		retf	2



;
; clear crt as `linear buffer' (not as rectangle)
; input:
; ds = 60h
; es = vram_segment
; DF = 0 (cld)
; dl,dh = clear from (scrren x,y)
; cl,ch = clear to (screen x,y)
; output:
; ax broken
nec98_crt_clrnr_noseg:
		push	cx
		push	di
		mov	al, 80
		mul	dh
		add	al, dl
		adc	ah, 0
		xchg	ax, di		; di = src vram addr / 2
		mov	al, 80
		mul	ch
		add	al, cl
		adc	ah, 0		; ax = dest vram addr / 2
		sub	ax, di
		jb	.exit
		inc	ax
		add	di, di		; src vram addr
		mov	cx, ax		; cx = fill count (by word)
		push	cx
		push	di
		xor	ah, ah
		mov	al, [_clear_char]
		rep	stosw
		pop	di
		pop	cx
		mov	al, [_clear_attr]
		add	di, 2000h
		rep	stosw
.exit:
		pop	di
		pop	cx
		ret

; ah = 0, 1, 2
; al = 'J' (0ah) or 'K' (0bh)
nec98_crt_escjk_seg:
		mov	cx, 60h
		mov	ds, cx
		mov	dh, [_cursor_y]
		mov	dl, [_cursor_x]
nec_98_crt_escjk_nosegdx:
		mov	ch, [_scroll_bottom]
		mov	cl, 79
		mov	es, [_text_vram_segment]
		cmp	al, 0ah
		je	nec98_crt_escj
		cmp	al, 0bh
		je	nec98_crt_esck
		sub	ah, '0'
		cmp	al, 'J'
		je	nec98_crt_escj
		cmp	al, 'K'
		je	nec98_crt_esck
		ret

nec98_crt_escj:
		cmp	ah, 0
		je	.do_clr
		cmp	ah, 1
		jne	.l2
		mov	cx, dx
		jmp	short .do_clr_dx0
.l2:
		cmp	ah, 2
		jne	nec98_crt_escj_exit
		xor	dx, dx
		call	nec98_update_curposdisp_noseg
.do_clr_dx0:
		xor	dx, dx
.do_clr:
		call	nec98_crt_clrnr_noseg
nec98_crt_redrawfuncline_noseg:
		cmp	byte [_function_flag], 0
		je	nec98_crt_escj_exit
		push	bx
		push	si
		call	nec98_crt_putfuncline
		pop	si
		pop	bx
nec98_crt_escj_exit:
		ret


nec98_crt_esck:
		mov	ch, dh
		cmp	ah, 0
		je	.do_clr
		cmp	ah, 1
		jne	.l2
		mov	cl, dl
		jmp	short .do_clr_dl0
.l2:
		cmp	ah, 2
		jne	.exit
.do_clr_dl0:
		xor	dl, dl
.do_clr:
		call	nec98_crt_clrnr_noseg
.exit:
		ret


; VOID ASMCONPASCAL_FAR nec98_crt_escjk_far(UBYTE ah_or_jkchar, UBYTE asc_or_binnum)
		global NEC98_CRT_ESCJK_FAR
NEC98_CRT_ESCJK_FAR:
		push	bp
		mov	bp, sp
arg_f jkchar, num
		push	cx
		push	dx
		push	ds
		push	es
		mov	al, [.jkchar]
		mov	ah, [.num]
		call	nec98_crt_escjk_seg
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bp
		retf 4

; VOID ASMCON_FAR nec98_redraw_funcs_far(VOID)
		global	_nec98_redraw_funcs_far
_nec98_redraw_funcs_far:
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es
		cld
		mov	ax, 60h
		mov	ds, ax
		call	nec98_crt_redrawfuncline_noseg
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		retf

; VOID ASMCONPASCAL_FAR nec98_crt_set_graph_far(UBYTE state)
		global	NEC98_CRT_SET_GRAPH_FAR
NEC98_CRT_SET_GRAPH_FAR:
		push	bp
		mov	bp, sp
arg_f state
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es
		cld
		mov	ax, 60h
		mov	ds, ax
		mov	al, [.state]
		mov	dx, 2001h
		cmp	al, 0
		je	.set
		mov	dx, 6700h
		cmp	al, 3
		jne	.exit
.set:
		mov	[_kanjigraph_mode], dx
		call	nec98_crt_redrawfuncline_noseg
.exit:
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	bp
		retf	2


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
		push	dx
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	bx, _esc_seq_cursor_pos
		mov	byte [0103h], 8		; fixed length (^[yy;xxR)
		mov	word [0104h], bx
		inc	bx
		inc	bx
		mov	dl, 10
		mov	al, [_cursor_y]
		call	.myitoap1
		inc	bx
		mov	al, [_cursor_x]
		call	.myitoap1
		pop	ds
		pop	dx
		pop	bx
		retf
.myitoap1:
		cmp	al, 98
		ja	.itoa_1
		mov	al, 98
.itoa_1:
		inc	al
		mov	ah, 0
		div	dl
		call	.itoa_w
		mov	al, ah
.itoa_w:
		add	al, '0'
		mov	[bx], al
		inc	bx
		ret

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

; input
;  ds = 60h
;  dl = old text attr
;  al = ansi color val (ESC[<num>m)
; result
;  al = new text attr
; bx, dx broken
nec98_crt_ansi2attr:
		cmp	al, 0		; 0m (set default)
		jne	.l0
		mov	al, [_clear_attr]
		or	al, 1		; always visible
		ret
.l_secret:
		mov	al, dl
		and	al, 0feh	; secret
		ret
.l0:
		mov	dh, dl
		mov	bx, .attr_0to7	; 1m...7m
		cmp	al, 8		; 8m (invisible)
		je	.l_secret
		jb	.l_cxlat
.l_color:
		and	dl, 1fh
		mov	bx, .attr_16to23
		sub	al, 16		; 16m...23m
		jz	.l_black	; 16m (black)
		cmp	al, 8
		jb	.l_cxlat
		mov	bx, .attr_30to37
		sub	al, 14		; 30m...37m
		jz	.l_black	; 30m (black)
		cmp	al, 8
		jb	.l_cxlat
		or	dl, 4		; reverse (on normal mode)
		sub	al, 10		; 40m...47m
		jz	.l_black	; 40m (black)
		cmp	al, 8
		jb	.l_cxlat
.l_unchange:
		mov	al, dh
		ret
.l_black:
		mov	al, dl
		ret
.l_cxlat:
		xlat
		cmp	al, 0
		jz	.l_unchange
		or	al, dl
		ret
.attr_0to7:
;		0,	1,	2,	3,	4,	5,	6,	7
	db	0,	0e0h,	10h,	0,	8,	2,	0,	4
.attr_16to23:
;		16,	17,	18,	19,	20,	21,	22,	23
	db	0,	40h,	20h,	60h,	80h,	0c0h,	0a0h,	0e0h
.attr_30to37:
;		30,	31,	32,	33,	34,	35,	36,	37
	db	0,	40h,	80h,	0c0h,	20h,	60h,	0a0h,	0e0h

; UBYTE ASMCONPASCAL_FAR nec98_crt_ansi2attr_far(UBYTE ansival, UBYTE oldattr);
		global NEC98_CRT_ANSI2ATTR_FAR
NEC98_CRT_ANSI2ATTR_FAR:
		push	bp
		mov	bp, sp
arg_f ansival, oldattr
		push	bx
		push	dx
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	al, [.ansival]
		mov	dl, [.oldattr]
		call	nec98_crt_ansi2attr
		pop	ds
		pop	dx
		pop	bx
		pop	bp
		retf

; input
; ds = 60h
; al = 's' (save) or 'u' (restore)
nec98_crt_escsu:
	cmp	al, 's'
	je	nec98_crt_csr_save
	cmp	al, 'u'
	je	nec98_crt_csr_restore
	ret
nec98_crt_csr_save:
	mov	al, [_put_attr]
	mov	[_save_cursor_attr], al
	mov	al, [_cursor_y]
	mov	ah, [_cursor_x]
	mov	[_save_cursor_y], ax
	ret
nec98_crt_csr_restore:
	push	dx
	mov	al, [_save_cursor_attr]
	mov	[_put_attr], al
%ifdef unsafe_crt_csr_restore
	mov	dl, [_save_cursor_x]
	mov	dh, [_save_cursor_y]
%else
	call	nec98_get_width
	mov	dl, [_save_cursor_x]
	cmp	dl, al
	jbe	.lx_end
	mov	dl, al
.lx_end:
	mov	dh, [_scroll_bottom]
	mov	al, [_save_cursor_y]
	cmp	dh, al
	jbe	.ly_end
	mov	dh, al
.ly_end:
%endif ; unsafe_crt_csr_restore
	call	nec98_update_curpos_noseg
	pop	dx
	ret

; VOID ASMCONPASCAL_FAR nec98_crt_escsu_far(char s_or_u);
		global NEC98_CRT_ESCSU_FAR
NEC98_CRT_ESCSU_FAR:
		push	bp
		mov	bp, sp
arg_f s_or_u
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	al, [.s_or_u]
		call	nec98_crt_escsu
		pop	ds
		pop	bp
		retf

; get dbcs lead byte as upper byte
; input
; ds = 60h
; output
; ah = dbcs lead byte or 0 (sbcs)
; al = 0
crt_get_kanji1:
		mov	ax, word [_kanji2_wait]
		test	al, al
		jne	.brk
		mov	ah, 0
.brk:
		mov	al, 0
		ret
; set dbcs lead byte
; input
; ds = 60h
; al = dbcs lead byte or 0 (sbcs)
; output
; ax 0=not dbcs lead, 1=dbcs lead
crt_set_kanji1:
		xor	ah, ah
		cmp	ah, [_kanjigraph_mode]
		je	.sb
		cmp	al, 81h
		jb	.sb
		cmp	al, 9fh
		jbe	.db
		cmp	al, 0e0h
		jb	.sb
		cmp	al, 0fch
		jbe	.db
.sb:
		xor	ax, ax
.db:
		mov	[_kanji1_code], al
		cmp	al, 0
		je	.brk
		mov	al, 1
.brk:
		mov	[_kanji2_wait], al
		ret

; UWORD ASMCON_FAR nec98_crt_get_kanji1_far(VOID)
		global _nec98_crt_get_kanji1_far
_nec98_crt_get_kanji1_far:
		push	ds
		mov	ax, 60h
		mov	ds, ax
		call	crt_get_kanji1
		pop	ds
		retf
; int ASMCONPASCAL_FAR nec98_crt_set_kanji1_far(UBYTE leadchar)
		global NEC98_CRT_SET_KANJI1_FAR
NEC98_CRT_SET_KANJI1_FAR:
		push	bp
		mov	bp, sp
arg_f leadchar
		push	ds
		mov	ax, 60h
		mov	ds, ax
		mov	al, [.leadchar]
		call	crt_set_kanji1
		pop	ds
		pop	bp
		retf	2


%endif		; INCLUDE_CONKEY60

%endif		; INCLUDE_CONSEG60
