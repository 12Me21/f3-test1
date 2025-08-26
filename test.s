		CPU 68020
		SUPMODE ON
		PADDING OFF
		ORG $000000

RESET_SP:	
		dc.l	$0041fffc
RESET_PC:	
		dc.l	entry

		dc.l [($60-*)/4]nop_rte
		ORG $60
SPURIOUS_INT:	
		dc.l	nop_rte
		dc.l 	nop_rte
		dc.l	vblank
		dc.l	vblank_2
		dc.l	nop_rte
		dc.l	timer
		dc.l	nop_rte
AVEC_7:	
		dc.l	nop_rte

		dc.l	$0

;;	dc.l [($400-*)/4]nop_rte

	ORG	$400
	
	;; A0: dest
	;; D1: count (bytes)
	;; uses: A2, D0, A0, D1
copyimm:
	movea.l	(SP), A2
	dbt	D1, .retn
.loop:
	move.b	(A2)+, (A0)+
	dbf	D1, .loop
.retn:
	addq.w	#$1,A2
	move.l	A2,D1
	bclr.l	#$0,D1
	move.l	D1,(SP)
	rts
	
COPYIMM	MACRO	dest, length
	lea	dest, A0
	move	length, D1
	jsr	copyimm
	ENDM
	
memcpyl:
.dest = 8
.src = .dest+4
.num = .src+4
.end = .num+2
	link.w	A6,#0
	movem.l	A1/A0/D1, -(SP)
	movea.l	(.dest,A6),A0
	movea.l	(.src,A6),A1
	move.w	(.num,A6),D1
	dbt	D1, .retn
.loop:
	move.l	(A1)+,(A0)+
	dbf	D1, .loop
.retn:
	movem.l	(SP)+, D0/D1/A0/A1
	unlk	A6
	rtd	#(.end-8)
	
font_def:
	INCLUDE "font.s"
	
;;; not position independent!
	ORG $5dde
sprintf:
	BINCLUDE "sprintf.bin"
	rts
	
;;; print string on stack
print_str:
strptr = $8
textram_loc = $c
color = $10
		link.w	A6,#$0
		movem.l	A1/A0/D7, -(SP)
		movea.l	(strptr,A6),A0
		movea.l	(textram_loc,A6),A1
		move.w	(color,A6),D7
		add.w		D7,D7
.loop:
		move.b	(A0)+,D0
		beq	.retn
		move.b	D7,(A1)+
		move.b	D0,(A1)+
		bra	.loop
.retn:
		move.l	A1,D0
		movem.l	(SP)+, D7/A0/A1
		unlk	A6
		rtd #$A

printf:
	link.w	A6,#-$40
	pea	($12,A6)
	move.l	($e,A6),-(SP)
	pea	(-$40,A6)
	jsr	sprintf
	move.w	($c,A6),-(SP)
	move.l	($8,A6),-(SP)
	pea	(-$40,A6)
	jsr	print_str
	unlk	A6
	rtd #$A
	
cursor = $400042
log:
.strptr = 8
.color = .strptr+4
.end = .color+2	
	link.w	A6,#$0
	movem.l	A1/A0/D7, -(SP)
	movea.l	(.strptr,A6),A0
	move.w	(.color,A6),D7
	add.w		D7,D7
.loop:
	move.b	(A0)+,D0
	beq	.retn
	move.l (cursor), A1
	move.b	D7,(A1)+
	move.b	D0,(A1)+
	addq.l #2, (cursor)
	andi.w #$CFFF, (cursor+2)
	bra	.loop
.retn:
	add.w #$7F, (cursor+2)
	andi.w #$FF80, (cursor+2)
	
	movem.l	(SP)+, D7/A0/A1
	unlk	A6
	rtd #(.end-8)

text_coord	FUNCTION x,y,$61c000 + 2*(y*$40 + x)
PRINT	MACRO charptr,x,y,color
		move.w 	color,-(SP)
		pea		(text_coord(x,y)).l
		pea		(charptr)
		nop
		jsr		(print_str)
		ENDM

lr_colscroll	FUNCTION pf,$624000 + $200*(pf)
lr_clipdef	FUNCTION cp,$625000 + $200*(cp)

lr_sp_prio	= $627600
lr_scale	FUNCTION pf,$628000 + $200*(pf)
lr_pal_add	FUNCTION pf,$629000 + $200*(pf)
lr_rowscroll	FUNCTION pf,$62a000 + $200*(pf)
lr_pf_prio	FUNCTION pf,$62b000 + $200*(pf)


FILL_W	MACRO dest,len,val
		lea	dest,A0
		move.w	len,D0
.fill_loop:
		move.w	val,(A0)+
		dbf	D0,.fill_loop
		ENDM

FILL_L	MACRO dest,len,val
		lea	dest,A0
		move.w	len,D0
.fill_loop:
		move.l	val,(A0)+
		dbf	D0,.fill_loop
		ENDM

;;; fill dest1 with val1 and dest2 with val2 for len [long]s
FILL_L2	MACRO dest1,dest2,len,val1,val2
		lea	dest1,A0
		lea	dest2,A1
		move.w	len,D0
.fill_loop:
		move.l	val1,(A0)+
		move.l	val2,(A1)+
		dbf	D0,.fill_loop
		ENDM

nop_rte:
		rte

reset_lineram:
		movem.l	A3/A2/A1/A0/D3/D2/D1/D0, -(SP)
		lea	(lineram_settings_table1,PC),A0
		lea	($624000).l,A1
		moveq	#$7,D3
		moveq	#$0,D0
		tst.b	(-$7ec2,A5)
		bne.b	.LAB_00005cf2
		moveq	#$30,D0
.LAB_00005cf2:
		adda.l	D0,A1
		move.w	D0,(-$7ec0,A5)
.LAB_00005cf8:
		move.w	(A0)+,D0
		bsr.b	memset_231
		move.w	(A0)+,D0
		bsr.b	memset_231
		move.w	(A0)+,D0
		bsr.b	memset_231
		move.w	(A0)+,D0
		bsr.b	memset_231
		lea	($800,A1),A1
		dbf	D3,.LAB_00005cf8
		lea	($620000).l,A1
		moveq	#$7,D3
		move.l	#$624000,D0
		lsr.l	#$8,D0
		lsr.l	#$4,D0
		lsl.l	#$8,D0
		lsl.l	#$2,D0
		addi.w	#$f,D0
		andi.w	#$7fff,D0
.LAB_00005d2e:
		move.w	#$ff,D1
.LAB_00005d32:
		move.w	D0,(A1)+
		dbf	D1,.LAB_00005d32
		ror.l	#$4,D2
		addi.w	#$400,D0
		dbf	D3,.LAB_00005d2e
		tst.w	(-$7ec2,A5)
		bne.w	.LAB_00005d56
		move.w	#$800,($626000).l
		bra.w	.LAB_00005d5e
.LAB_00005d56:
		move.w	#$800,($6261fe).l
.LAB_00005d5e:
		movem.l	(SP)+, D0/D1/D2/D3/A0/A1/A2/A3
		rts	
	
memset_231:
		move.w	#$e7,D1
.loop:
		move.w	D0,(A1)+
		dbf	D1,.loop
		lea	($30,A1),A1
		rts
	
lineram_settings_table1:
		dc.w $0000,$0000,$0000,$0000
		dc.w $0000,$0000,$0000,$0000
		dc.w $00fb,$bbbb,$7000,$0000
		dc.w $0000,$300f,$0300,$aa88
		dc.w $0080,$0080,$0080,$0080
		dc.w $0000,$0000,$0000,$0000
		dc.w $0000,$0000,$0000,$0000
		dc.w $3002,$3009,$300c,$300d

load_game_font:
		lea	(font_def).l,A0
		move.w	#$2ff,D0
		lea	($61e000).l,A1
.LAB_00005b86:
		move.l	(A0)+,D1
		;; swap...
		swap	D1
		move.l	D1,(A1)+
		dbf	D0,.LAB_00005b86
		move.w	#$7,D0
		lea	($61f200).l,A1
.LAB_00005b9a:
		clr.l	(A1)+
		dbf	D0,.LAB_00005b9a
		rts

playfield_scroll_params_reset:
PF_SCROLL_REGS = $4000d8
ram_flipscreen = -$7ec2	
		movem.l	A0, -(SP)
		lea	(PF_SCROLL_REGS).l,A0
		tst.w	(ram_flipscreen,A5)
		bne.w	.flip_scroll_defaults
		move.w	#-$a00,(A0)+
		move.w	#-$80,(A0)+
		move.w	#-$900,(A0)+
		move.w	#-$c00,(A0)+
		move.w	#-$800,(A0)+
		move.w	#-$c00,(A0)+
		move.w	#-$700,(A0)+
		move.w	#-$80,(A0)+
		move.w	#$29,(A0)+
		move.w	#$18,(A0)+
		bra.w	.end
.flip_scroll_defaults:
		move.w	#-$5a00,(A0)+
		move.w	#-$7480,(A0)+
		move.w	#-$5900,(A0)+
		move.w	#-$8000,(A0)+
		move.w	#-$5800,(A0)+
		move.w	#-$8000,(A0)+
		move.w	#-$5700,(A0)+
		move.w	#-$7480,(A0)+
		move.w	#$9e,(A0)+
		move.w	#$100,(A0)+
.end:
		movem.l	(SP)+, A0
		rts	

PF_0_TILES = $610000
PF_1_TILES = $612000
PF_2_TILES = $614000
PF_3_TILES = $616000
PVT_TILES = $61c000
PVT_X = $660018
PVT_Y = $66001A
reset_pivot:
	movem.l	A0/D1/D0, -(SP)
	move.l	#$2900290,D1
	FILL_L (PVT_TILES).l, #$7ff, D1
	moveq	#$0,D1
	move.w	D1,(-$7ef2,A5)
	move.w	D1,(-$7eee,A5)
	move.l	D1,(-$7eca,A5)
	move.w	D1,(-$7ec6,A5)
	moveq #(24), D1
	move.w	D1,PVT_Y
	moveq #(42), D1
	move.w	D1,PVT_X
	movem.l	(SP)+, D0/D1/A0
	rts	
reset_tilemap_0:
		movem.l	A1/A0/D1/D0, -(SP)
		moveq	#$0,D1
		FILL_L (PF_0_TILES).l, #$7ff, D1
		FILL_L (lr_rowscroll(0)).l, #$ff, D1
		move.l	D1,(-$7f12,A5)
		move.l	D1,(-$7f0e,A5)
		move.l	D1,(-$7eea,A5)
		move.l	D1,(-$7ee6,A5)
		movem.l	(SP)+, D0/D1/A0/A1
		rts
reset_tilemap_1:
		movem.l	A1/A0/D1/D0, -(SP)
		moveq	#$0,D1
		FILL_L (PF_1_TILES).l, #$7ff, D1
		FILL_L (lr_rowscroll(1)).l, #$ff, D1
		move.l	D1,(-$7f0a,A5)
		move.l	D1,(-$7f06,A5)
		move.l	D1,(-$7ee2,A5)
		move.l	D1,(-$7ede,A5)
		movem.l	(SP)+, D0/D1/A0/A1
		rts
reset_tilemap_2:
		movem.l	A1/A0/D2/D1/D0, -(SP)
		moveq	#$0,D1
		FILL_L (PF_2_TILES).l, #$7ff, D1
		FILL_L (lr_rowscroll(2)).l, #$ff, D1
		move.w	#$80,D1
		moveq	#$0,D2
		FILL_L2	(lr_scale(2)).l, (lr_colscroll(2)).l, #$ff, D1, D2
		move.l	D2,(-$7f02,A5)
		move.l	D2,(-$7efe,A5)
		move.l	D2,(-$7eda,A5)
		move.l	D2,(-$7ed6,A5)
		movem.l	(SP)+, D0/D1/D2/A0/A1
		rts
reset_tilemap_3:
		movem.l	A1/A0/D2/D1/D0, -(SP)
		moveq	#$0,D1
		FILL_L (PF_3_TILES).l, #$7ff, D1
		FILL_L (lr_rowscroll(3)).l, #$ff, D1
		move.w	#$80,D1
		moveq	#$0,D2
		FILL_L2	(lr_scale(3)).l, (lr_colscroll(3)).l, #$ff, D1, D2
		move.l	D2,(-$7efa,A5)
		move.l	D2,(-$7ef6,A5)
		move.l	D2,(-$7ed2,A5)
		move.l	D2,(-$7ece,A5)
		movem.l	(SP)+, D0/D1/D2/A0/A1
		rts

reset_text_tilemaps_lineram:
		jsr	reset_pivot
		jsr	reset_tilemap_0
		jsr	reset_tilemap_1
		jsr	reset_tilemap_2
		jsr	reset_tilemap_3
		jsr	reset_lineram
		rts

SPRITERAM_TOP = $600000
SPRITERAM_BODY = $600010
SPRITE	MACRO dest,tile,zoom,xpos,ypos,blockctrl,palette
		move.w tile, (dest)
		move.w zoom, ($2,dest)
		move.w xpos, ($4,dest)
		move.w ypos, ($6,dest)
		move.w blockctrl, ($8,dest)
		move.w palette, ($A,dest)
		ENDM

reset_spriteram:
		movem.l	A1/A0/D0, -(SP)
		;; bsr.w	clear_spriteram_etc
		lea	($600000).l,A0
		lea	($600010).l,A1
		SPRITE A0, #0, #0, #$3000, #$8000, #0, #0, #0, #0
		SPRITE A1, #0, #0, #$3000, #$8000, #0, #0, #0, #0
		lea	($608000).l,A0
		lea	($608010).l,A1
		SPRITE A0, #0, #0, #$3000, #$8000, $0, $0, $0, #0
		SPRITE A1, #0, #0, #$3000, #$8000, #0, #0, #0, #0
		movem.l	(SP)+, D0/A0/A1
		rts	

PALETTE_RAM = $440000
load_system_palettes:
	move.w	#(15*16), -(SP)
	pea	palettes
	pea	PALETTE_RAM
	bsr	memcpyl
	rts
	
palettes:
	dc.l	$00000000, $00303030, $00404040, $00505050
	dc.l	$00606060, $00707070, $00808080, $00909090
	dc.l	$00000000, $00101010, $00202020, $00303030
	dc.l	$00404040, $00505050, $00606060, $00707070
	dc.l	$00000000, $00000000, $00000000, $00909090
	dc.l	$00000000, $00000000, $00000000, $00000000
	dc.l	$00000000, $00000000, $00000000, $00000000
	dc.l	$00000000, $00000000, $00000000, $00000000
	dc.l	$00c0a058, $0000f800, $00f83838, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $0008f808, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0008b0f8, $0008b0f8, $000068e0
	dc.l	$000000a0, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0068b0f8, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $00f8f808, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $00a848f8, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $0058f8f8, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $00f8f8f8, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $00f850f8, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$0000d8a0, $0000f800, $00c89840, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$0000d8a0, $0000f800, $00888888, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00c0a058, $0000f800, $00f8f8f8, $0000a000
	dc.l	$000000f8, $00585858, $00e04880, $00500058
	dc.l	$00208808, $0090f880, $00d87800, $00f8f808
	dc.l	$004098e8, $000040d0, $00b048c0, $00801898
	dc.l	$00f80090, $00f8f8f8, $00502880, $0000f800
	dc.l	$0000f800, $0000f800, $0000f800, $0000f800
	dc.l	$0000f800, $0000f800, $0000f800, $0000f800
	dc.l	$0000f800, $0000f800, $0000f800, $0000f800
	dc.l	$00f80090, $00f8f8f8, $00502880, $00000000
	dc.l	$0000f800, $0000f800, $0000f800, $0000f800
	dc.l	$0000f800, $0000f800, $0000f800, $0000f800
	dc.l	$0000f800, $0000f800, $0000f800, $0000f800
	
s_WAIT_A_MOMENT:
	dc.b	"WAIT FOR EVER %X!\0"
	ALIGN 2

RAM_BASE = $408000
entry:
	lea (RAM_BASE).l, A5
	nop
	
	move.l #$61c000, cursor
	jsr	load_game_font
	jsr	playfield_scroll_params_reset
	jsr	reset_text_tilemaps_lineram
	jsr	reset_spriteram
	jsr	load_system_palettes
	;; jsr	clear_shared_ram_
	;; jsr	Z_reset_3FF_3FE_E0_1_FF
	;; jsr	coin_exchange_rate_init_
	
	move.l 	#5, -(SP)
	pea	s_WAIT_A_MOMENT
	move.w	#$8, -(SP)
	pea	(text_coord(14,15)).l
	jsr	printf
	lea	($4,SP),SP
	
	move.w	#$8, -(SP)
	pea s_WAIT_A_MOMENT
	jsr log
.loop:
	
	jmp .loop


FIO_0 = $4a0000
vblank:
		moveq	#$0, D0
		move.b	D0, (FIO_0).l
		rte
vblank_2:
		rte
timer:
		rte

