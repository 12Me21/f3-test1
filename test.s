		CPU 68020
		SUPMODE ON
		PADDING OFF
		ORG $000000
	
COLS = 39
status_height = 2
row_delta = $80
cursor_domain = $DFFF
TEXT_RAM = $61C000
	
PVT_X = $660018
PVT_Y = $66001A
PIVOT_PORT = $621000
LINERAM = $620000
SPRITE_RAM = $600000
FIO_0 = $4a0000

RAM_BASE = $408000
cursor = $400044
pvy = $400040
counter1 = $400048
abcd = $400050
vblank_pc = $400100
old_btn = $400180
rising_btn = $400184
edit = $400200
edit_addr = $400204

fixed_bfextu macro source, start, length, dest
	bfextu source{32-start-length:length}, dest
	endm
	
disable_interrupts	macro
	ori.w #$700, SR
	endm

enable_interrupts	macro
	andi.w #(~$700), SR
	endm

kick_watchdog macro
	move.b	#0, FIO_0
	endm
	
RESET_SP:	
	dc.l	$41FFFC
RESET_PC:	
	dc.l	entry
	org $8
	dc.l [2]ex_access
	org $10
	dc.l inst_error
	org $14
	dc.l [5]default_interrupt
	org $28
	dc.l ex_a_line
	dc.l ex_f_line
	dc.l [($60-*)/4]default_interrupt
	ORG $60
	dc.l	error
	dc.l 	error
	dc.l	vblank
	dc.l	vblank_2
	dc.l	error
	dc.l	timer
	dc.l	error
	dc.l	error
	dc.l	error

;;	dc.l [($400-*)/4]nop_rte

	ORG	$400
spin:
	stop #$2000
	;dc.w $8AFA
	bra spin
	
print_ex_stack:
	move.w (SP,4+0), (abcd+2)
	move.l (SP,4+2), (abcd+4)
	move.l (SP,4+6), (abcd+8)
	disable_interrupts
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l #0, D0
	move.w (abcd+10),D0
	move.l 	D0, -(SP)
	move.l 	(abcd+4), -(SP)
	move.w (abcd+2),D0
	move.l D0, -(SP)
	pea.l .msg
	jsr logf
	lea.l	(4*3,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rts
.msg:
	dc.b	"ex: SR:%04X @:%08X %04X\0"
	align 2
	
	
ex_access:	
	disable_interrupts
	pea.l .msg
	jsr logf
	jsr print_ex_stack
	enable_interrupts
	rte
.msg:
	dc.b	"mem error!\0"
	ALIGN 2
	
ex_a_line:
	disable_interrupts
	pea.l .msg
	jsr logf
	jsr print_ex_stack
	enable_interrupts
	rte
.msg:
	dc.b	"A-LINE ERROR!\0"
	ALIGN 2
	
ex_f_line:
	disable_interrupts
	pea.l .msg
	jsr logf
	jsr print_ex_stack
	enable_interrupts
	rte
.msg:
	dc.b	"F-LINE ERROR!\0"
	ALIGN 2
	
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
	
skip_str_imm:						  ;temp
	movea.l	(SP), A2
.loop:
	tst.b	(A2)+
	bne	.loop
	addq.w	#1,	A2
	move.l A2, D7
	bclr.l	#0, D7
	move.l D7,(SP)
	rts
	
memcpyl:
.dest equ.l 8
.src equ.l .dest+4
.num equ.w .src+4
.end equ .num+2
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
	;INCLUDE "font.s"
	INCLUDE "font2.s"
	
;;; not position independent!
	ORG $5dde
sprintf:
	BINCLUDE "sprintf.bin"
	rts
	
;;; print string on stack
print_str:
.strptr = 8
.dest = .strptr+4
.color = .dest+4
	link.w	A6,#$0
	movem.l	A1/A0/D7/D1/D0, -(SP)
	movea.l	(.strptr,A6),A0
	movea.l	(.dest,A6),A1
	move.w	(.color,A6),D7
	bfins D7, D7{32-9-4:4}
.loop:
	jsr procchar
	bne .loop
	move.l	A1,D0
	movem.l	(SP)+, D0/D1/D7/A0/A1
	unlk	A6
	rtd #$A

printf:
.dest = 8
.color = .dest+4
.format = .color+2
.rest = .format+4
.buffer = -$40
	link.w	A6,#.buffer
	pea	(.rest,A6)
	move.l	(.format,A6),-(SP)
	pea	(.buffer,A6)
	jsr	sprintf
	move.w	(.color,A6),-(SP)
	move.l	(.dest,A6),-(SP)
	pea	(.buffer,A6)
	jsr	print_str
	unlk	A6
	rtd #$A
	
logf:
.format = 8
.rest = .format+4	
.buffer = -$80
	link.w	A6,#.buffer
	pea	(.rest,A6)
	move.l	(.format,A6),-(SP)
	pea	(.buffer,A6)
	jsr	sprintf
	move.w	(.format,A6),-(SP)
	pea	(.buffer,A6)
	jsr	log
	unlk	A6
	rtd #$4
	
	;; D0 - dest (modified) - todo: would be nice if this was A1
	;; A1,D1 - used
log_newline:
	;; move to next line and clear it
	bfclr	D0{32-1-6:6} 		  ; carriage return
	addi.w #row_delta, D0		  ; line feed
	andi.w #cursor_domain, D0
	move.l D0, A1
	move.l #(COLS-1), D1
.loop1:
	clr.w (A1)+
	dbf	D1, .loop1
	rts
	
	;; D7 - attrs (modified)
	;; A0 - source (modified)
	;; A1 - dest (modified)
	;; D0, D1 - used
	;; flags: zero if we read a terminator
procchar:
	;; read a char
	move.b	(A0)+,D7
	beq .ret
	bgt .putch
	;; control
	move.b	(A0)+,D7
	bfins D7, D7{32-9-4:4}
	rts
.putch:
	cmp.b #$A,D7
	beq .newline
	;; check if at end of line
	move.l A1, D0
	bfextu	D0{32-1-6:6}, D1  ;get x
	cmpi.w	#COLS,D1
	blt	.ok1
.newline:
	jsr	log_newline
	move.l D0, A1
.ok1:
	move.w	D7,(A1)+
.ret:
	rts
	
;; uses D0
log_adj_scroll:	
	;; scroll so that cursor is at a particular line
	move.l cursor, D0
	bfextu D0{32-7-6:6}, D0 ;extract y coordinate
	mulu.w #-8, D0	;convert to negative pixels
	addi.w #(256-8-(status_height*8)), D0 				  ;put it to line 256
	move.w D0, PVT_Y
	rts
	
; text ram address format: [110y yyyy yXXX XXX0]
log:
.strptr = 8
.end = .strptr+4
	disable_interrupts
	link.w	A6,#0
	movem.l	A1/A0/D7/D1/D0, -(SP)
	movea.l	(.strptr,A6),A0
	move #(10<<1<<8), D7
	move.l (cursor), A1
.loop:
	jsr procchar
	bne .loop

.finished:
;	move.w #$0601,(A1)
	move.l A1, (cursor)
	jsr log_adj_scroll
	
	movem.l	(SP)+, D7/D1/D0/A0/A1
	unlk	A6
	enable_interrupts 			  ;todo: dont just re-enable here, restore old value
	rtd #(.end-8)
	
drop macro amt
	lea.l	(amt,SP),SP
	endm
	
status_bar:
	move.l (cursor), D0
	jsr log_newline
	move.l D0, A2
	jsr log_newline
	move.l A2, A1
	
	move.l (rising_btn-2),-(SP)
	
;	moveq.l #0, D0
;	move.w $4A000A, D0
										  ;	ror.w #8, D0
	move.l edit_addr, A0
	moveq.l #0, D0
	move.l (A0), D0
	
	move.l D0,-(SP)
	move.l edit-2,-(SP)
	move.l A0,-(SP)
	move.l SP,-(SP)
	move.l (vblank_pc),-(SP)
	move.l (counter1),-(SP)
	pea .msg
	move.w #12, -(SP)
	move.l A1, -(SP)
	jsr printf
	drop 4*7
	rts
.msg:
	dc.b "f%d pc%06X sp%06X\nedit:%06X[%d]=%08X btn:%2X\0"
	align 2
	
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
	;; [pppp pppp aaaa mmmm]
	;; p - address
	;; a - latch alternate
	;; m - latch normal
	
setup_scroll:	
	move.w	#24,PVT_Y
	move.w	#(41+(40-COLS)*8/2),PVT_X
	rts
	
setup_pivot_port:
	lea PIVOT_PORT, A0
	move.w #$00F0, (A0)+
	move.w #$1000, D0
	lsr.w #1, D0
	subq.w #2, D0
	moveq #0, D1
.cpp:
	move.b #0,$4a0000
	move.w D1, (A0)+
	dbf D0, .cpp
	rts
	
setup_lineram:
	lea .defaults, A1
	lea LINERAM, A0
	move.l #($1000-$400), D4
	moveq	#7, D2
.loop1:
	addi.w #$40F, D4
	move.l #255, D1
.loop2:
	move.w D4, (A0)+
	move.b #$00, D4
	dbf D1, .loop2
	
	;; put the value
	lea $620000, A3
	move.w D4, D3
	lsl.w #2, D3
	adda.w D3, A3
	
	move.w (A1)+, (A3)
	adda.w #$200, A3
	move.w (A1)+, (A3)
	adda.w #$200, A3
	move.w (A1)+, (A3)
	adda.w #$200, A3
	move.w (A1)+, (A3)
	adda.w #$200, A3
	
	;; 
	dbf D2, .loop1
	rts
	
.defaults:
	dc.w 0,0,0,0
	dc.w 0,0,0,0
	dc.w $02FF, $BDB9, $7000, $0037
	dc.w $0001, $300F, $0300, $7DDD
	dc.w $0080, $0080, $0080, $0080
	dc.w $0000, $0000, $0000, $0000
	dc.w $003F, $003F, $003F, $003F
	dc.w $100B, $1009, $1003, $1001
	
lineram_settings_table1:
	dc.w $0000,$0000,$0000,$0000
	dc.w $0000,$0000,$0000,$0000
	dc.w $00fb,$bbbb,$7000,$0000
	dc.w $0000,$300f,$0300,$aa88
	dc.w $0080,$0080,$0080,$0080
	dc.w $0000,$0000,$0000,$0000
	dc.w $0000,$0000,$0000,$0000
	dc.w $3002,$3009,$300c,$300d
	
setup_sprites:	
	lea .defaults, A1
	lea SPRITE_RAM, A0
	move.l	#(8*3-1), D0
.loop:
	move.w	(A1)+, (A0)+
	dbf D0, .loop
	rts
.defaults:
	dc.w	$0000, $FFFF, $0000, $8000, $0000, $0000, $0000, $0000
	dc.w	$0000, $FFFF, $A02E, $0018, $0000, $0000, $0000, $0000
	dc.w	$0000, $FFFF, $5000, $0000, $0000, $0000, $8002, $0000
	
load_game_font:
	lea font_def, A0
	lea $61E000, A1
	move.w #(128*32/4-1),D0
.loop:
	move.l (A0)+,(A1)+
	dbf	D0, .loop
	rts

PALETTE_RAM = $440000
load_system_palettes:
	move.w	#(15*16), -(SP)
	pea	palettes
	pea	PALETTE_RAM
	jsr	memcpyl
	
	moveq #10, D0
	lea ($440000+(4*16*2)), A0
.loop:
	move.l (8,A0),D1
	move.l #0,(4,A0)
	lsr #1,D1
	andi.l #$007F7F7F,D1
	move.l D1,($C,A0)
	adda #(4*16),A0
	dbf D0, .loop
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
	
s_INTMSG
	dc.b	"GOT INTERRUPT %08X %08X!\0"
	ALIGN 2
s_ERRBAD
	dc.b	"BAD ERROR %08X!\0"
	ALIGN 2
	
entry:
	disable_interrupts
	lea (RAM_BASE).l, A5
	nop
	move.l #TEXT_RAM, cursor
	
	; setup fio
	move.b #0,$4a0000
	move.b #255,$4a0006
	move.b #0,$4a0004
	move.b #0,$4a0014
	; interrupt timer disable
	move.w #$0000,$4c0000
	; pf control
	move.w #$80,$66001e
	;; clear graphics ram
	move.l #$FFFF, D0
	lea $600000, A0
.loop1:
	move.l #0, (A0)+
	dbf D0, .loop1
	;;  setup pivot port?
	jsr 	setup_sprites
	jsr	setup_scroll
	jsr	setup_pivot_port
	jsr	setup_lineram
	jsr	load_game_font
	jsr	load_system_palettes
	
	jsr log_adj_scroll
	move.l #0, edit
	move.l #0, edit_addr
	
	moveq.l #6, D6
	enable_interrupts
	bra spin
	
s_WAIT_A_MOMENT:
	dc.b	"WAIT FOR EVER %X -- \xFF\x10 HI!\0"
	ALIGN 2
	
s_frame:	
	dc.b	"FRAME:\xFF%c%d\0"
	align 2
	
loop:
	;move.l counter1, D0
	;move.l 	D0, -(SP)
	;move.l 	#4, -(SP)
	;pea.l s_frame
	;jsr logf
	;lea.l	($8,SP),SP
	
	;moveq.l #0, D0
	;move.b $4A000B, D0
	;lsl.w #8, D0
	;move.b $4A000A, D0
	
	;move.l 	D0, -(SP)
	;move.l 	D0, -(SP)
	;pea.l s_WAIT_A_MOMENT
	;jsr logf
	;lea.l	($8,SP),SP
	
	addq.l #1, counter1
	;; read btns
	move.b $4A0003, D0
	lsl #8, D0
	move.b $4A0007, D0
	move.w old_btn, D1
	move.w D0, old_btn
	
	eori.w #-1, D0
	and.w D0, D1
	move.w D1, rising_btn
	;; 
	move.w edit, D2
	btst #2, D1
	beq .n1
	subi.w #1,D2
.n1:
	btst #3, D1
	beq .n2
	addi.w #1,D2
.n2:
	andi.w #7,D2
	move.w D2,edit
	;; 
	moveq.l #1,D0
	lsl.l #2,D2
	lsl.l D2,D0
	btst #0, D1
	beq .n3
	subi.l D0,(edit_addr)
.n3:
	btst #1, D1
	beq .n4
	addi.l D0,(edit_addr)
.n4:
	;; 
	btst #8, D1
	beq .n5
	move.l edit_addr, A0
	dc.w $AAAA
	move.l #0, -(SP)
	move.l #1, -(SP)
	pea.l .mem_report
	jsr logf
	drop 4*2
.n5:
	rts
.mem_report:
	dc.s "test\n\0"
	align 2
	
vblank:
	disable_interrupts
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	kick_watchdog
	jsr loop
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	move.l (SP,2), (vblank_pc)
	;jsr print_ex_stack
	jsr status_bar
	enable_interrupts
	rte

timer:
	rte
vblank_2:
	rte
	
error:
	disable_interrupts
	move.l (SP), (abcd)
	move.l (SP,4), (abcd+4)
	move.l (SP,8), (abcd+8)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd+8), -(SP)
	pea.l s_ERRBAD
	jsr logf
	lea.l	($4,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	enable_interrupts
	rte
	
inst_error:
	move.l (SP,2), (abcd)
	disable_interrupts
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd), -(SP)
	pea.l .msg
	jsr logf
	lea.l	($4,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	jsr print_ex_stack
	enable_interrupts
	rte
.msg:
	dc.b	"INST ERROR! %08X\0"
	ALIGN 2
	
	
default_interrupt:
	disable_interrupts
	move.l (SP), (abcd)
	move.l (SP,4), (abcd+4)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd), -(SP)
	move.l 	(abcd+4), -(SP)
	pea.l s_INTMSG
	jsr logf
	lea.l	($8,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	enable_interrupts
	rte
