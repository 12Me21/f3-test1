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
FIO = $4a0000
PF_CONTROL = $660000
	
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
das = $400300

disable_interrupts	macro
	ori.w #$700, SR
	endm

enable_interrupts	macro
	andi.w #(~$700), SR
	endm

kick_watchdog macro
	move.b	#0, FIO+0
	endm
	
drop macro amt
	IF amt<>0
	lea.l	(amt,SP),SP
	ENDIF
	endm
	
logf3 macro count, str
	jsr logf2
	dc.b str, "\0"
	align 2
	drop count*4
	endm

logf4 macro count, str
	pea .string
	jsr logf
	bra .next
.string:
	dc.b str, "\0"
	align 2
.next:
	drop count*4
	endm

push    macro   op
        move.ATTRIBUTE op,-(sp)
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

	rts
	dc.b "e!"
	;bcs *+2 ; can't
	
print_ex_stack:
	move.w (SP,4+0), (abcd+2)
	move.l (SP,4+2), (abcd+4)
	move.l (SP,4+6), (abcd+8)
	;disable_interrupts
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l #0, D0
	move.w (abcd+10),D0
	push.l D0
	push.l (abcd+4)
	move.w (abcd+2),D0
	push.l D0
	logf4 3, "ex: SR:%04X @:%08X %04X"
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rts
	
FAIL_STOP:	
	stop #$2F00
	rts
	
ex_access:	
	logf4 0, "mem error!"
	jsr print_ex_stack
	rte
	
ex_a_line:
	logf4 0, "A-LINE ERROR!"
	jsr print_ex_stack
	rte

ex_f_line:
	logf4 0, "F-LINE ERROR!\0"
	jsr print_ex_stack
	rte


	;; D0 - value
	;; D7 - attr (low byte modified)
	;; A4 - print dest (modified)
print_hex_digit:
	;bfextu D0{0:4}, D1 			  ;highest nibble
	rol.l #4, D0
	move.b D0, D7
	andi.b #$F, D7
	cmpi.b #9,D7
	ble .small
	addq.b #$7, D7
.small:
	addi.b #$30, D7
	move.b D7, (A4)+
	rts
	;moveq #0, D1
	;bfins D0, D1{32-4-3:4}		  ;d1 = [0nnn n000]
	;abcd D1, D1						  ;d1 = [nnnn 0..0] x = carry

;; A0 - source
;; A4 - print dest
;; D0, D1, D7 - modified
print_hexl_line:
.buffer = -$80
	link.w	A6,#(.buffer)
	lea (.buffer,A6), A4
	move.l A0, D0
	andi.l #(~$F), D0
	move.l D0, A0
	lsl.l #8, D0
	move.l #$2000, D7
	jsr print_hex_digit
	jsr print_hex_digit
	jsr print_hex_digit
	jsr print_hex_digit
	jsr print_hex_digit
	;jsr print_hex_digit
	move.b #'o', (A4)+
	move.b #'|', (A4)+
	
	move.l #(4-1), D1
.loop:
	move.l (A0)+, D0
	;move.l #$1100, D7
	move.b #255, (A4)+
	move.b #$17, (A4)+
	jsr print_hex_digit
	jsr print_hex_digit
	;move.l #$1000, D7
	move.b #255, (A4)+
	move.b #$19, (A4)+
	jsr print_hex_digit
	jsr print_hex_digit
	;move.l #$1100, D7
	move.b #255, (A4)+
	move.b #$18, (A4)+
	jsr print_hex_digit
	jsr print_hex_digit
	;move.l #$1000, D7
	move.b #255, (A4)+
	move.b #$19, (A4)+
	jsr print_hex_digit
	jsr print_hex_digit
	dbf D1, .loop
	
	move.b #0, (A4)+
	
	move.l A4, D0
	bfclr	D0{32-1-6:6} 		  ; carriage return
	addi.w #row_delta, D0		  ; line feed
	andi.w #cursor_domain, D0
	move.l D0, A4
	lea (.buffer,A6), A4
	unlk	A6
	rts
	
	
hex_report:	
	movem.l	A4/A1/A0/D7/D3/D1/D0, -(SP)
	;move.l (edit_addr), D0
	;bfextu D0{8:24}, D0
	logf4 0, "------+00112233445566778899AABBCCDDEEFF\n"

	move.l D0, A0
	move.l #10, D3
.loop:
	jsr print_hexl_line
	;move.b #0, (A4)+
	
	push.l A4
	logf4 1, "%s\n\0"
	
	dbf D3, .loop
	;; 
	
	logf4 0, " \n"
	
	movem.l	(SP)+, A4/A1/A0/D7/D3/D1/D0
	rts
	
	
	
	;; A0: dest
	;; D1: count (bytes)
	;; uses: A2, D0, A0, D1
copyimm:
	movea.l	(SP), A2
	bra .entry
.loop:
	move.b	(A2)+, (A0)+
.entry:
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
	
get_imm_str:
	
	
	
	jmp (A6)
	
	
	
	;; 
;	movea.l (SP)+, A2
	
push_imm_str:						  ;temp
	movea.l (SP), A2
.loop:
	tst.b	(A2)+
	bne .loop
	addq.l #1, A2
	move.l A2, D7
	bclr.l #0, D7
	jmp (D7)
	
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
	bra .entry
.loop:
	move.l	(A1)+,(A0)+
.entry:
	dbf	D1, .loop
.retn:
	movem.l	(SP)+, D1/A0/A1
	unlk	A6
	rtd	#(.end-8)
	
;;; not position independent ?
;	ORG $5dde
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
	link.w	A6,#(.buffer)
	movem.l	A1/A0/D1/D0, -(SP)
	pea	(.rest,A6)
	move.l	(.format,A6),-(SP)
	pea	(.buffer,A6)
	jsr	sprintf
	drop 4*3
	pea	(.buffer,A6)
	jsr	log
	movem.l	(SP)+, D0/D1/A0/A1
	unlk	A6
	rtd #$4
	
	org $10000
logf2:
.return = 4
.rest = 8
.buffer = -$80
	link.w	A6,#(.buffer)
	movem.l	A1/A0/D1/D0, -(SP)
	pea (.rest,A6)
	move.l (.return,A6), A0
	move.l A0, -(SP)
.loop:
	move.b (A0)+, D0
	bne .loop
	move.l A0, D0
	addq.l #1, D0
	bclr.l #0, D0
	move.l D0, (.return,A6)
	pea	(.buffer,A6)
	jsr	sprintf
	drop 4*3
	pea	(.buffer,A6)
	jsr	log
	movem.l	(SP)+, D0/D1/A0/A1
	unlk	A6
	rts
	
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
	cmp.b #1,D0
	rts
.putch:
	cmp.b #$A,D7
	bne .not_newline
	;; \n
	jsr	log_newline
	move.l D0, A1
	cmp.b #1,D0 					  ; ugh
	bra .ret
.not_newline:
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
	cmp.b #1,D0
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
	link.w	A6,#0
	movem.l	A1/A0/D7/D6/D1/D0, -(SP)
	move.w SR, D6 					  ; todo: what if we use a trap instead of a function for logging, that way it restores the SR automatically ?
	disable_interrupts
	
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
	
	move.w D6, SR
	movem.l	(SP)+, D0/D1/D6/D7/A0/A1
	unlk	A6
	rtd #(.end-8)
	
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
	move.l edit-2,-(SP)
	move.l A0,-(SP)
	move.l SP,-(SP)
	move.l (vblank_pc),-(SP)
	move.l (counter1),-(SP)
	pea .msg
	move.w #12, -(SP)
	move.l A1, -(SP)
	jsr printf
	drop 4*6
	rts
.msg:
	dc.b "f%d pc%06X sp%06X\nedit:%06X[%d] btn:%2X\0"
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
	lea control_defaults, A1
	lea PF_CONTROL, A0
	move.l #(16-1), D0
.loop:
	move.w (A1)+, (A0)+
	dbf D0, .loop
	
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
	
	;; (A0)+ -> (A3)
	;; uses D1,D0
write_lineram_block:	
	move.w (A1)+, D0
	move.l #(256-1), D1
.loop3:
	move.w D0, (A3)+
	dbf D1, .loop3
	rts
	
	;; D4 -> A3
	;; uses D3
latch_to_addr:	
	bfextu D4{32-10-4:4}, D3
	mulu.w #$1000, D3
	lea $620000, A3
	add.l D3, A3
	rts
	
	;; [??mm mmM? LLLL llll]
setup_lineram:
	lea lineram_defaults, A1
	lea LINERAM, A0
	move.w #($4<<10), D4
	moveq	#(8-1), D2
.loop1:
	move.b #$0F, D4
	move.l #(256-1), D1
.loop2:
	move.w D4, (A0)+
	move.b #$00, D4
	dbf D1, .loop2
	
	;; put the value
	jsr latch_to_addr
	
	;link A6, #0
	push.l A3
	push.l D3
	logf4 2, "lineram write to: %x %x\n"
	;unlk A6 ; what if we did this or something instead of the manual drop?
	
	bsr write_lineram_block
	bsr write_lineram_block
	bsr write_lineram_block
	bsr write_lineram_block
	
	;; 
	addi.w #($1<<10), D4
	dbf D2, .loop1
	rts
	
	;789abcdef
lineram_defaults:
	dc.w $0000, $0000, $0000, $0000 ;colscroll
	dc.w $0000, $0000, $0000, $0000 ;clip
	dc.w $0255, $9bdf, $7000, $0037
	;; (outdated:)
	;; pf alpha disabled (00)
	;; pivot alpha enabled (01,select=1)
	;; sprites alpha enabled (01,select=1)
	;; pivot->pf: pivot uses blend 1, pf uses blend 4
	;; pf+pf: uses blend 4 and 2
	;; sprites select=0: sprite->pf: sprite uses blend 2, pf uses blend 4
	;; sprites select=1: sprite->pf: sprite uses blend 1, pf uses blend 4
	
	;; ok so  select determines: 0 = 2 and 4, 1 = 1 and 3  for itself only?
	
	
	dc.w $0001, $300F, $0300, $5555 ;7000
	dc.w $0080, $0080, $0080, $0080 ;pf scale
	dc.w $0000, $0000, $0000, $0000 ;palette add
	dc.w $003F, $003F, $003F, $003F ;rowscroll
	dc.w ($3001|$0000), $1009, $1003, $1001 ;pf prio
control_defaults:	
	dc.w $D5A7,$F77F,$F87F,$F97F,$EF88,$F400,$F400,$F400
	dc.w $0000,$0000,$0000,$0000,$0029,$0018,$0000,$0000
;	dc.w $F67F,$F77F,$F87F,$F77F,$F400,$F400,$F400,$F400
;	dc.w $0000,$0000,$0000,$0000,$0029,$0018,$0000,$0000

lineram_defaults_old:
	dc.w $0000,$0000,$0000,$0000
	dc.w $0000,$0000,$0000,$0000
	dc.w $00fb,$bbbb,$7000,$0000
	dc.w $0000,$300f,$0300,$aa88
	dc.w $0080,$0080,$0080,$0080
	dc.w $0000,$0000,$0000,$0000
	dc.w $0000,$0000,$0000,$0000
	dc.w $3002,$3009,$300c,$300d

setup_tiles:	
	lea $610000, A0
	move.l #(64*32-1), D1
	move.l #$00021862, D0
.loop:
	move.l D0, (A0)+
	dbf D1, .loop
	rts
	
setup_sprites:	
.count = 3+8
	lea .defaults, A1
	lea SPRITE_RAM, A0
	move.l	#(8*.count-1), D0
.loop:
	move.w	(A1)+, (A0)+
	dbf D0, .loop
;; 2nd bank
	lea .defaults2, A1
	lea SPRITE_RAM+$8000, A0
	move.l	#(8*.count-1), D0
.loop2:
	move.w	(A1)+, (A0)+
	dbf D0, .loop2
	
	move.w #$83FF, $604000-16+12
	move.w #$8BFF, $60C000-16+12
	
	rts
.defaults:
	dc.w $0000, $FFFF, $0000, $8000, $0000, $0000, $0000, $0000
	dc.w $0000, $FFFF, $A02E, $0018, $0000, $0000, $0000, $0000
	dc.w $0000, $FFFF, $5000, $0000, $0000, $0000, $0000, $0000
	dc.w $0000, $0000, $00F0, $0038, $0801, $0000, $00FF, $0000
	dc.w $3BE0, $0000, $0000, $0000, $7801, $0000, $0000, $0000
	dc.w $3BE1, $0000, $0000, $0000, $7801, $0000, $0000, $0000
	dc.w $3BE2, $0000, $0000, $0000, $7801, $0000, $0000, $0000
	dc.w $3BE3, $0000, $0000, $0000, $7801, $0000, $0000, $0000
	dc.w $3BE4, $0000, $0000, $0000, $7801, $0000, $0000, $0000
	dc.w $3BE5, $0000, $0000, $0000, $7801, $0000, $0000, $0000
	dc.w $0000, $0000, $0000, $0000, $7001, $0000, $0000, $0000
.defaults2:
	dc.w $0000, $FFFF, $0000, $8000, $0000, $0000, $0000, $0000
	dc.w $0000, $FFFF, $A02E, $0018, $0000, $0000, $0000, $0000
	dc.w $0000, $FFFF, $5000, $0000, $0000, $0000, $0000, $0000
	dc.w $0000, $0000, $00A0, $0038, $0805, $0000, $00FF, $0000
	dc.w $3BE0, $0000, $0000, $0000, $7805, $0000, $0000, $0000
	dc.w $3BE1, $0000, $0000, $0000, $7805, $0000, $0000, $0000
	dc.w $3BE2, $0000, $0000, $0000, $7805, $0000, $0000, $0000
	dc.w $3BE3, $0000, $0000, $0000, $7805, $0000, $0000, $0000
	dc.w $3BE4, $0000, $0000, $0000, $7805, $0000, $0000, $0000
	dc.w $3BE5, $0000, $0000, $0000, $7805, $0000, $0000, $0000
	dc.w $0000, $0000, $0000, $0000, $7005, $0000, $0000, $0000
	
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
	;; correct text colors hack
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
	;; sprite palettes
	move.w #(9*16), -(SP)
	pea sprite_palette
	pea PALETTE_RAM+$4000
	jsr memcpyl
	
	rts
	
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
	move.b #0,$4a0006
	move.b #255,$4a0016
	move.b #0,$4a0004
	move.b #0,$4a0014
	; interrupt timer disable
	move.w #$0000,$4c0000
	; pf control
	;move.w #$80,$66001e
	;; clear graphics ram
	move.l #$FFFF, D0
	lea $600000, A0
.loop1:
	clr.l (A0)+
	dbf D0, .loop1
	;;
	jsr 	setup_sprites
	jsr	setup_scroll
	jsr	setup_pivot_port
	jsr	setup_lineram
	jsr	load_game_font
	jsr	load_system_palettes
	
	jsr	setup_tiles
	
	jsr log_adj_scroll
	move.l #0, edit
	move.l #0, edit_addr
	
	moveq.l #6, D6
	;enable_interrupts
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
	
	;move.l counter1, D0
	
	;move.w #10000, D1
	;lea $610000, A0
	
	;addi.w #1, ($660008)
	;addi.w #1, ($660000)
	;addi.w #1, ($660004)
;	move.w (counter1+2), $660000
	;move.w (counter1+2), $660008
	
	addq.l #1, counter1
	cmpi.l #60, counter1
	ble .ret 						  ; ignore buttons in the first second
	;; read btns
	jsr process_inputs
.ret:
	rts
	
	;; let's arrange: 
	;; up down left right b1 b2 b3 start
buttons:	
.read_p1:
	move.b FIO+2, D0
	bfextu D0{32-4-1:1}, D0
	bfins D0, D1{32-7-1:1}
	move.b FIO+3, D0
	bfextu D0{32-0-3:3}, D0
	bfins D0, D1{32-4-3:3}
	move.b FIO+7, D0
	bfextu D0{32-0-4:4}, D0
	bfins D0, D1{32-0-4:4}
	move D1, D0
	;; do repeats
	
	move.w old_btn, D4
	move.w D0, old_btn
	
	move.w D0, D2
	eor.w #-1, D2
	and.w D4, D2
	
	move.w D0, D3
	eor.w #-1, D4
	and.w D4, D3
	
	eor.w #-1, D0
	
	moveq.l #7, D4
	moveq.l #0, D1
.loop1:
	btst D4, D2
	beq .notnew
	move.b #20, (das,D4)
	bra .hit
.notnew:
	btst D4, D0
	beq .waiting
	subi.b #1, (das,D4)
	bne .waiting
	move.b #3, (das,D4)
.hit:	
	bset D4, D1
	movem.l	D4/D3/D2/D1/D0, -(SP)
	move.l (.blist, D4*4), A0
	push.l A0
	logf4 1, "btn jump %x\n"
	jsr (A0)
	movem.l	(SP)+, D4/D3/D2/D1/D0
.waiting:
	dbf D4, .loop1

	rts
.down:
	move.w edit, D2
	lsl #2, D2
	moveq.l #1, D0
	lsl.l D2, D0
	subi.l D0, edit_addr
	rts
.up:
	move.w edit, D2
	lsl #2, D2
	moveq.l #1, D0
	lsl.l D2, D0
	addi.l D0, edit_addr
	rts
.right:
	subi.w #1, edit
	andi.w #$7, edit
	rts
.left:
	addi.w #1, edit
	andi.w #$7, edit
	rts
.a:
	bfextu edit_addr{8:24},D0
	jsr hex_report
	bra .skip
	move.l D0, A0
	move.l (A0), D0
	push.l D0
	push.l A0
	logf4 2, "\xFF\x04read [%6X] -> %08X\n\0abcdef"
	move.b D0, edit_addr
.skip:
	rts
.b:
	bfextu edit_addr{8:24},D0
	move.l D0, A0
	moveq.l #0, D0
	move.b edit_addr, D0
	move.b D0, (A0)
	push.l D0
	push.l A0
	logf4 2, "\xFF\x02write[%6X] <- %02X\n"
	rts
.c:
	rts
.start:
	rts
.blist:
	dc.l .up, .down, .left, .right, .a, .b, .c, .start
	
process_inputs:
	;; read buttons
	jsr buttons.read_p1
	;push.l D1
	;logf4 1, "btn: %x\n"
	rts
	
vblank:
	disable_interrupts
	move.l (SP,2), (vblank_pc)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	
	cmp.l #END_PRG, (vblank_pc)
	ble .okay
	stop #$2F00
.okay
	kick_watchdog
	
	jsr loop
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	
	;jsr print_ex_stack
	jsr status_bar
	enable_interrupts
	rte
	
timer:
	rte
vblank_2:
	rte
	
error:
	move.l (SP), (abcd)
	move.l (SP,4), (abcd+4)
	move.l (SP,8), (abcd+8)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd+8), -(SP)
	pea.l s_ERRBAD
	jsr logf
	lea.l	($4,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rte
	
inst_error:
	move.l (SP,2), (abcd)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd), -(SP)
	pea.l .msg
	jsr logf
	lea.l	($4,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	jsr print_ex_stack
	rte
.msg:
	dc.b	"INST ERROR! %08X\0"
	ALIGN 2
	
	
default_interrupt:
	move.l (SP), (abcd)
	move.l (SP,4), (abcd+4)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd), -(SP)
	move.l 	(abcd+4), -(SP)
	pea.l s_INTMSG
	jsr logf
	lea.l	($8,SP),SP
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rte
	
END_PRG:	
	

	
font_def:
	;INCLUDE "font.s"
	INCLUDE "font2.s"
	
palettes:
	dc.l $000000, $303030, $404040, $505050, $606060, $707070, $808080, $909090, $000000, $101010, $202020, $303030, $404040, $505050, $606060, $707070
	dc.l $000000, $000000, $000000, $909090, $000000, $000000, $000000, $000000, $000000, $000000, $000000, $000000, $000000, $000000, $000000, $000000
	dc.l $c0a058, $00f800, $f83838, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $08f808, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $08b0f8, $08b0f8, $0068e0, $0000a0, $585858, $e04880, $500058, $208808, $68b0f8, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $f8f808, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $a848f8, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $58f8f8, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $f8f8f8, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $f850f8, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $00d8a0, $00f800, $c89840, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $00d8a0, $00f800, $888888, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $c0a058, $00f800, $f8f8f8, $00a000, $0000f8, $585858, $e04880, $500058, $208808, $90f880, $d87800, $f8f808, $4098e8, $0040d0, $b048c0, $801898
	dc.l $f80090, $f8f8f8, $502880, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800
	dc.l $f80090, $f8f8f8, $502880, $000000, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800, $00f800
sprite_palette:
	dc.l $000000, $F7F787, $C7C757, $979727, $F7F7B7, $F7F7F7, $A7C7F7, $67B7F7, $0F9FF7, $3777EF, $1747EF, $1717C7, $1717A7, $3F3F8F, $272777, $171727
	dc.l $000000, $FFC707, $D79F07, $BF7707, $FFFF07, $F7F7F7, $F7B7BF, $FF979F, $FF6F7F, $F74757, $E72F37, $C70F17, $A70717, $870717, $670717, $171717
	dc.l $000000, $EFEF07, $C7C70F, $AFA71F, $FFFF87, $F7F7F7, $E7F7E7, $BFF7BF, $7FF77F, $07EF07, $07BF07, $079707, $0F7F0F, $1F671F, $3F5F3F, $2F372F
	dc.l $000000, $07EFEF, $07CFCF, $07AFAF, $B7F7F7, $F7F7F7, $F7F7AF, $F7F77F, $F7F73F, $E7E717, $CFCF17, $A7A717, $878717, $6F6F17, $5F5F17, $4F4F17
	dc.l $000000, $F7F757, $DF9F07, $DF6F07, $F7F7B7, $FFF7F7, $FFE7B7, $FFD77F, $FFC73F, $FFBF07, $EF9707, $C77707, $9F5F07, $7F4F07, $5F4707, $570707
	dc.l $000000, $EFDF07, $D7A707, $BF7707, $F7F797, $F7F7F7, $E7C7F7, $E79FF7, $CF3FF7, $B717EF, $8F17BF, $771797, $67177F, $4F176F, $2F1747, $171717
	dc.l $000000, $B7B7B7, $9F9F9F, $7F7F7F, $DFDFDF, $FFFFFF, $EFEFEF, $DFDFE7, $CFCFDF, $BFBFD7, $AFAFC7, $9F9FBF, $8F8FB7, $7F7FAF, $6F6FA7, $5F5F9F
	dc.l $000000, $FFFF67, $FFE707, $FFAF07, $FFFFA7, $FFFFFF, $E7DFDF, $CFC7C7, $B7AFAF, $9F9797, $877F7F, $6F6767, $574F4F, $3F3737, $271F1F, $170707
	dc.l $000000, $7F97E7, $FF0707, $C7EFFF, $FF976F, $67777F, $7F8757, $97972F, $AFA707, $B7BF07, $B7CF07, $CFDF37, $D7E767, $E7EF97, $E7EFC7, $FFFFFF
