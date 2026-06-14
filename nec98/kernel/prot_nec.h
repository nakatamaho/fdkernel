#if !defined(PROTO_NEC_HEADER) && defined(NEC98)
# define PROTO_NEC_HEADER

/* configurations */
# define USE_PUTCRT_SEG60 1
# define USE_PROGKEY_SEG60 1
# define USE_ANSI2ATTR 1


# define ASMCON  ASMCFUNC
# define ASMCON_FAR  FAR ASMCFUNC
# define ASMCONPASCAL_FAR  FAR ASMPASCAL

# define ASMSUP  ASMCFUNC
# define ASMSUP_FAR  FAR ASMCFUNC
# define ASMSUPPASCAL_FAR  FAR ASMPASCAL


/* kernel,asm */
UWORD  ASMPASCAL bios_peekw_pascal(UWORD off);
# if defined(__WATCOMC__) && (__WATCOMC__) >= 1250
UWORD  __watcall bios_peekw_watcall(UWORD off);
UBYTE  __watcall iosys_peekb_watcall(UWORD off);
#pragma aux (__watcall) bios_peekw_pascal modify exact [ax]
#pragma aux (__watcall) iosys_peekb_watcall modify exact [ax]
#  define bios_peekw  bios_peekw_watcall
#  define iosys_peekb iosys_peekb_watcall
# else
#  define bios_peekw  bios_peekw_pascal
#  define iosys_peekb(o) peekb(0x60,o)
# endif
# define bios_peekb(o)  (UBYTE)bios_peekw(o)

/* console.asm */

/* UBYTE  ASMCON crt_set_mode(UBYTE mode); */
VOID  ASMCON set_curpos(UBYTE x, UBYTE y);
/* VOID  ASMCON crt_scroll_up(VOID); */
UBYTE  ASMCON get_crt_width(VOID);
UBYTE  ASMCON get_crt_height(VOID);
UBYTE  ASMCON get_crt_posx(VOID);
UBYTE  ASMCON get_crt_posy(VOID);
VOID  ASMCON put_crt(UBYTE x, UBYTE y, UWORD c);
VOID  ASMCON put_crt_wattr(UBYTE x, UBYTE y, UWORD c, UBYTE a);
VOID  ASMCON clear_crt(UBYTE x, UBYTE y);
VOID  ASMCON update_cursor_view(VOID);
/* VOID  ASMCON crt_rollup(UBYTE lines); */
/* VOID  ASMCON crt_rolldown(UBYTE lines); */

UBYTE FAR *  ASMPASCAL nec98_programmable_key_table(unsigned index);
VOID  ASMPASCAL nec98_set_cnvkey_table(UBYTE index);
VOID  ASMPASCAL nec98_get_programmable_key(void far *keydata, unsigned keyindex);
VOID  ASMPASCAL nec98_set_programmable_key(const void far *keydata, unsigned keyindex);

/* conkey60.asm */
UWORD ASMCONPASCAL_FAR nec98_getset_ctrlfunc_far(UWORD r_ax);

# ifdef USE_PROGKEY_SEG60
UBYTE FAR *  ASMCONPASCAL_FAR nec98_programmable_key_table_far(unsigned index);
VOID  ASMCONPASCAL_FAR nec98_set_cnvkey_table_far(UBYTE index);
VOID  ASMCONPASCAL_FAR nec98_set_programmable_key_far(const void far *keydata, unsigned keyindex);
VOID  ASMCONPASCAL_FAR nec98_get_programmable_key_far(void far *keydata, unsigned keyindex);
# endif

/* conseg60.asm */

UBYTE  ASMCONPASCAL_FAR nec98_crt_set_mode_far(UBYTE mode);
UBYTE  ASMCONPASCAL_FAR nec98_crt_rollup_far(UBYTE linecnt);
UBYTE  ASMCONPASCAL_FAR nec98_crt_rolldown_far(UBYTE linecnt);
VOID  ASMCON_FAR nec98_crt_scroll_up_far(VOID);

VOID  ASMCONPASCAL_FAR nec98_put_crt_far(UBYTE x, UBYTE y, UWORD ccode);
VOID  ASMCONPASCAL_FAR nec98_put_crt_wattr_far(UBYTE x, UBYTE y, UWORD ccode, UWORD attr);
VOID  ASMCONPASCAL_FAR nec98_clear_crt_far(UBYTE x, UBYTE y);
VOID  ASMCONPASCAL_FAR nec98_clear_crt_n_far(UBYTE x, UBYTE y, UWORD count);
VOID  ASMCONPASCAL_FAR nec98_set_curpos_far(UBYTE x, UBYTE y);
VOID  ASMCONPASCAL_FAR nec98_set_curpos_clipped_far(UBYTE x, UBYTE y, UBYTE ofs);
VOID  ASMCONPASCAL_FAR nec98_move_curpos_rel_far(UBYTE direction, UWORD count);
UWORD  ASMCONPASCAL_FAR nec98_show_hide_cursor_far(UBYTE showhide);
VOID   ASMCONPASCAL_FAR nec98_update_cursor_view_far(VOID);

UWORD  ASMCONPASCAL_FAR nec98_sjis2jis_far(UWORD sjis);

VOID  ASMCON_FAR push_cursor_pos_to_conin(VOID);
VOID  ASMCON_FAR nec98_console_esc6n_far(VOID);

VOID  ASMCONPASCAL_FAR nec98_put_func_index_far(UBYTE x, UBYTE y, UWORD index);
VOID  ASMCON_FAR nec98_put_funcs_far(VOID);
VOID  ASMCON_FAR nec98_clear_funcs_far(VOID);
VOID  ASMCON_FAR nec98_redraw_funcs_far(VOID);

VOID ASMCONPASCAL_FAR nec98_crt_escjk_far(UBYTE ah_or_jkchar, UBYTE asc_or_binnum);
VOID ASMCONPASCAL_FAR nec98_crt_setmodenh_far(UBYTE hln);

VOID  ASMCONPASCAL_FAR nec98_crt_escsu_far(char s_or_u);
UWORD  ASMCON_FAR nec98_crt_get_kanji1_far(VOID);
int  ASMCONPASCAL_FAR nec98_crt_set_kanji1_far(UBYTE leadchar);
VOID  ASMCONPASCAL_FAR nec98_crt_set_graph_far(UBYTE state);

UBYTE  ASMCONPASCAL_FAR nec98_crt_ansi2attr_far(UBYTE ansival, UBYTE oldattr);


/* kernel.asm + supseg60.asm */

VOID ASMSUPPASCAL_FAR nec98_sup_get_scsi_devices_far(VOID FAR *p);
UWORD ASMSUP_FAR nec98_sup_get_machine_type_far(VOID);
VOID ASMSUPPASCAL_FAR nec98_sup_get_daua_list_far(VOID FAR *p);


#if defined __WATCOMC__
#pragma aux (pascal) bios_peekw_pascal modify exact [ax]

#pragma aux clear_crt modify exact [ax]
#pragma aux get_crt_width modify exact [ax]
#pragma aux get_crt_height modify exact [ax]
#pragma aux get_crt_posx modify exact [ax]
#pragma aux get_crt_posy modify exact [ax]
#pragma aux put_crt modify exact [ax]
#pragma aux put_crt_wattr modify exact [ax]
#pragma aux set_curpos modify exact [ax dx]
#pragma aux update_cursor_view modify exact [ax dx]

#pragma aux (pascal) nec98_crt_set_mode_far modify exact [ax]

#pragma aux (pascal) nec98_programmable_key_table modify exact [ax dx]
#pragma aux (pascal) nec98_set_cnvkey_table modify exact [ax dx]
#pragma aux (pascal) nec98_get_programmable_key modify exact [ax cx dx]
#pragma aux (pascal) nec98_set_programmable_key modify exact [ax cx dx]
# ifdef USE_PROGKEY_SEG60
#pragma aux (pascal) nec98_programmable_key_table_far modify exact [ax dx]
#pragma aux (pascal) nec98_set_cnvkey_table_far modify exact [ax]
#pragma aux (pascal) nec98_get_programmable_key_far modify exact [ax]
#pragma aux (pascal) nec98_set_programmable_key_far modify exact [ax]
# endif

#pragma aux nec98_set_console_esc6n_far modify exact [ax]
#pragma aux (pascal) nec98_crt_rollup_far modify exact [ax dx]
#pragma aux (pascal) nec98_crt_rolldown_far modify exact [ax dx]
#pragma aux nec98_crt_scroll_up_far modify exact [ax dx]

#pragma aux (pascal) nec98_put_crt_far modify exact [ax]
#pragma aux (pascal) nec98_put_crt_wattr_far modify exact [ax]
#pragma aux (pascal) nec98_clear_crt_far modify exact [ax]
#pragma aux (pascal) nec98_set_curpos_far modify exact [ax]
#pragma aux (pascal) nec98_set_curpos_clipped_far modify exact [ax]
#pragma aux (pascal) nec98_move_curpos_rel_far modify exact [ax]
#pragma aux (pascal) nec98_show_hide_cursor_far modify exact [ax]
#pragma aux (pascal) nec98_update_cursor_view_far modify exact [ax]

#pragma aux (pascal) nec98_sjis2jis_far modify exact [ax]

#pragma aux (pascal) nec98_crt_escjk_far modify exact [ax]
#pragma aux (pascal) nec98_crt_setmodenh_far modify exact [ax]

#pragma aux (pascal) nec98_put_func_index_far modify exact [ax dx]
#pragma aux nec98_put_funcs_far modify exact [ax]
#pragma aux (pascal) nec98_crt_escsu_far modify exact [ax]
#pragma aux nec98_clear_funcs_far modify exact [ax]
#pragma aux nec98_redraw_funcs_far modify exact [ax]
#pragma aux nec98_crt_get_kanji1_far modify exact [ax]
#pragma aux (pascal) nec98_crt_set_kanji1_far modify exact [ax]
#pragma aux (pascal) nec98_crt_set_graph_far modify exact [ax]
#pragma aux (pascal) nec98_crt_ansi2attr_far modify exact [ax]

#pragma aux (pascal) nec98_getset_ctrlfunc_far modify exact [ax]

#pragma aux (pascal) nec98_sup_get_scsi_devices_far modify exact [ax]
#pragma aux nec98_sup_get_machine_type_far modify exact [ax]
#pragma aux (pascal) nec98_sup_get_daua_list_far modify exact [ax]
#endif


#define set_cnvkey_table nec98_set_cnvkey_table

#define crt_set_mode  nec98_crt_set_mode_far
#define crt_rollup  nec98_crt_rollup_far
#define crt_rolldown  nec98_crt_rolldown_far
#define crt_scroll_up  nec98_crt_scroll_up_far

#ifdef USE_PUTCRT_SEG60
/* in console.asm */
# define set_curpos nec98_set_curpos_far
# define update_cursor_view  nec98_update_cursor_view_far
# define put_crt  nec98_put_crt_far
# define put_crt_wattr  nec98_put_crt_wattr_far
# define clear_crt  nec98_clear_crt_far
/* in int29dc.c */
# define set_curpos_clipped nec98_set_curpos_clipped_far
# define sjis2jis  nec98_sjis2jis_far
# define put_func_index  nec98_put_func_index_far
# define put_funcs  nec98_put_funcs_far
# define clear_funcs  nec98_clear_funcs_far
#endif

#ifdef USE_PROGKEY_SEG60
# define nec98_programmable_key_table  nec98_programmable_key_table_far
# define nec98_set_cnvkey_table  nec98_set_cnvkey_table_far
# define nec98_get_programmable_key  nec98_get_programmable_key_far
# define nec98_set_programmable_key  nec98_set_programmable_key_far
#endif



#endif

