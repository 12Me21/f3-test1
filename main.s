		CPU 68020
		SUPMODE ON
		PADDING ON
		ORG $000000
	
	;; memory mapped address constants
TIMER_CONTROL = $4C0000
GRAPHICS_0 = $600000
SOUND_RESET_ASSERT = $C80100
SOUND_RESET_CLEAR = $C80000

TEXT_RAM = $61C000

DPRAM_0 = $C00000
PVT_X = $660018
PVT_Y = $66001A
PIVOT_PORT = $621000
LINERAM = $620000
SPRITE_RAM = $600000
FIO = $4a0000
PF_CONTROL = $660000

	
RAM_BASE = $408000
pvy = $400040
counter1 = $400048
abcd = $400050
vblank_pc = $400100
old_btn = $400180
rising_btn = $400184
edit = $400200
edit_addr = $400204
das = $400300
	
parser_variables = $400500
parser_state = $400500
parser_next = parser_state+4
parser_acc = parser_next+4
parser_acc_len = parser_acc+4

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
	
printf4 macro count, str
	pea .string
	pea .next
	jmp printf
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
	dc.l _entry
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

	Include "shared-ram.s"
	
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
	printf4 3, "ex: SR:%04X @:%08X %04X"
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rts
	
FAIL_STOP:	
	stop #$2F00
	rts
	
ex_access:	
	printf4 0, "mem error!"
	jsr print_ex_stack
	rte
	
ex_a_line:
	printf4 0, "A-LINE ERROR!"
	jsr print_ex_stack
	rte

ex_f_line:
	printf4 0, "F-LINE ERROR!\0"
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
	;addi.w #row_delta, D0		  ; line feed
	;andi.w #cursor_domain, D0
	move.l D0, A4
	lea (.buffer,A6), A4
	unlk	A6
	rts
	
hex_report:	
	movem.l	A4/A1/A0/D7/D3/D1/D0, -(SP)
	;move.l (edit_addr), D0
	;bfextu D0{8:24}, D0
	printf4 0, "------+00112233445566778899AABBCCDDEEFF\n"

	move.l D0, A0
	move.l #10, D3
.loop:
	jsr print_hexl_line
	;move.b #0, (A4)+
	
	push.l A4
	printf4 1, "%s\n\0"
	
	dbf D3, .loop
	;; 
	
	printf4 0, " \n"
	
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
	
printf:
.format = 8
.rest = .format+4
.buffer = -$80
	link.w A6, #.buffer
	movem.l	A2/A1/A0/D7/D1/D0, -(SP)
	pea	(.rest,A6)
	move.l	(.format,A6), -(SP)
	pea	(.buffer,A6)
	jsr sprintf
	drop 4*3
	lea (.buffer,A6), A2
	lea STDOUT_0, A1
	jsr buffer_begin_write
.loop:
	move.b (A2)+, D0
	beq .exit
	jsr buffer_push
	bra .loop
.exit:
	jsr buffer_end_write
	movem.l	(SP)+, A2/A1/A0/D7/D1/D0
	unlk A6
	rtd #$4
	
setup_scroll:	
	lea control_defaults, A1
	lea PF_CONTROL, A0
	move.l #(16-1), D0
.loop:
	move.w (A1)+, (A0)+
	dbf D0, .loop
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
	mulu.w #($1000/2), D3 		  ;div by 2 so it's not negative lol
	lea ($620000, D3*2), A3
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
	printf4 2, "lineram write to: %x %x\n"
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

setup_fio:	
	move.b #0,$4a0000
	move.b #0,$4a0006
	move.b #255,$4a0016
	move.b #0,$4a0004
	move.b #0,$4a0014
	rts
	
setup_graphics_ram:	
	move.l #$FFFF, D0
	lea GRAPHICS_0, A0
.loop1:
	clr.l (A0)+
	dbf D0, .loop1
	rts
	
setup_timer:	
	move.w #$0000, TIMER_CONTROL
	rts
	
setup_audio_shared:	
	clr.w SOUND_RESET_ASSERT
	lea DPRAM_0, A1
	move.w #($200-1), D1
.loop:
	clr.l (A1)+
	dbf D1, .loop
	jsr	setup_shared
	clr.w SOUND_RESET_CLEAR
	rts
	
_entry:
	disable_interrupts
	lea (RAM_BASE).l, A5
	nop
	jsr setup_audio_shared
	pea s_WAIT_A_MOMENT
	jsr printf
	drop 1*4
	
	clr.l counter1
	jsr setup_fio
	; setup fio
	; interrupt timer disable
	
	; pf control
	;move.w #$80,$66001e
	;; clear graphics ram
	jsr setup_timer
	jsr setup_graphics_ram
	
	jsr 	setup_sprites
	jsr	setup_scroll
	jsr	setup_pivot_port
	jsr	setup_lineram
	jsr	load_game_font
	jsr	load_system_palettes
	
	jsr	setup_tiles
	
	move.l #ps_default, parser_state
	
	bra spin
	
s_WAIT_A_MOMENT:
	dc.b	"WAIT FOR EVER %X -- \x1B[31m HI!\x1B[m\n", 0
	ALIGN 2
	
s_frame:	
	dc.b	"FRAME:\xFF%c%d\0"
	align 2

loop:
	addq.l #1, counter1
	cmpi.l #30, counter1
	ble .n1 						  ; ignore buttons in the first half second
	;; read btns
	jsr process_inputs
.n1:
	
	;; jsr stdout_begin
	;; push.l A1
	;; push.l A0
	;; jsr stdout_end
	
	;; printf4 2, "stdout %x/%x\n"
	lea STDIN_0, A1
	jsr buffer_begin_read
	bra .read_start
.read:
	clr.l D0
	jsr buffer_pop
	;push.l parser_state
	;push.l D0
	;printf4 2, "got byte: %x in state %x\n"
	move.l D0, D5
	bsr got_byte
.read_start
	jsr buffer_check_remaining
	bne .read
	jsr buffer_end_read
	
.ret:
	rts

	;; D0
got_byte:	
	movem.l	A1/D6/D7, -(SP)
	jsr ([parser_state])
	movem.l	(SP)+, A1/D6/D7
	rts
	
ps_default:
	cmp.b #'A', D5
	bne .n1
	move.l #ps_address, parser_state
	move.l #ps_command_p, parser_next
	move.w #6-1, parser_acc_len
	clr.l parser_acc
	rts
.n1:
	cmp.b #'w', D5
	bne .n2
	move.l #ps_address, parser_state
	move.l #ps_command_w, parser_next
	move.w #8-1, parser_acc_len
	clr.l parser_acc
	rts
.n2:
	
	rts
	
ps_address:	
	move.w D5, D0
	bsr hex_char_to_ascii
	bmi .fail
	move.l parser_acc, D2
	lsl.l #4, D2
	;add.w parser_acc_len, D0
	add.b D0, D2
	move.l D2, parser_acc
	subq.w #1, parser_acc_len
	bmi .end
	rts
.end:
	move.l parser_next, parser_state
	rts
.fail:
	;; reset
	clr.l D0
	move.w parser_acc, D0
	push.l D0
	printf4 1, "bad addr. %x\n"
	
	move.l #ps_default, parser_state
	jmp ([parser_state])
	

ps_command_p:
	move.l #ps_default, parser_state
	
	move.l parser_acc, A0
	clr.l D0
	move.b (A0), D0
	
	push.l D0
	push.l A0
	push.l #.msg
	jsr printf
	drop 4*2
	
	rts
.msg:
	dc.b "READ:@%6X=%2X\n\0"
	align 2

ps_command_w:
	move.l #ps_default, parser_state
	move.l parser_acc, D0
	push.l D0
	printf4 1, "w%8X"
	
	move.b D0, D1
	lsr.l #8, D0
	move.l D0, A0
	move.b D1, (A0)
	printf4 0,"/\n"
	rts

	;; TODO: add a version that uses MOVES so we can test the different address spaces.

puts:									  ; takes A2 (todo: just use stack params)
	movem.l	A1/D0/D6/D7, -(SP)	
	lea STDOUT_0, A1
	jsr buffer_begin_write
.loop:
	move.b (A2)+, D0
	beq .exit
	jsr buffer_push
	bra .loop
.exit:
	jsr buffer_end_write
	;move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
	movem.l	(SP)+, A1/D0/D6/D7
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
	;push.l A0
	;printf4 1, "btn jump %x\n"
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
	printf4 2, "\xFF\x04read [%6X] -> %08X\n\0abcdef"
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
	printf4 2, "\xFF\x02write[%6X] <- %02X\n"
	rts
.c:
	lea s_WAIT_A_MOMENT, A2 
	jsr puts
	
	lea 0, A0
	movem.l (A0), D0/D1/D2
	push.l D0
	push.l D1
	push.l D2
	printf4 3, "movem: %x,%x,%x\n"
	movem.l (A0), D0/D1/D2
	push.l D0
	push.l D1
	push.l D2
	printf4 3, "movem: %x,%x,%x\n"
	rts
	push.l #1
	push.l #5
	jsr function
	;move (SP)+, D0
	printf4 1, "result: %d\n"
	;0100 1000 0111 1000 
	;dc.w $4878, $ABCD
	pea ($7BCD).w
	move.l ($7BCD).w, D0
;	push.l A0
	printf4 1, "addr: %x\n"
	
	
	rts
.start:
	rts
.blist:
	dc.l .up, .down, .left, .right, .a, .b, .c, .start
	
process_inputs:
	;; read buttons
	jsr buttons.read_p1
	;push.l D1
	;printf4 1, "btn: %x\n"
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
	printf4 1, "BAD ERROR %08X!\n"
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rte
	
inst_error:
	move.l (SP,2), (abcd)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd), -(SP)
	printf4 1, "INST ERROR! %08X\n"
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	jsr print_ex_stack
	rte
	
default_interrupt:
	move.l (SP), (abcd)
	move.l (SP,4), (abcd+4)
	movem.l	A6/A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	move.l 	(abcd), -(SP)
	move.l 	(abcd+4), -(SP)
	printf4 2, "GOT INTERRUPT %08X %08X!"
	movem.l	(SP)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/A6
	rte

function:
.arg1 = 8+4
.out1 = 8+4
.arg2 = 8
.local1 = 0-4
   link A6, #-4
	movem.l D0, -(SP)
   move.l (.arg1, A6), (.local1, A6)
	move.l (.arg2, A6), D0
	add.l D0, (.local1, A6)
   move.l (.local1, A6), (.out1, A6)
	movem.l (SP)+, D0
   unlk A6
   rtd #4 ; (because there's 1 fewer output than input)
	
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

	movem.w	D4/D3/D2/D1/D0, (A0) ; ah but this still increments
	;; like i thought maybe we could do
	movem.w (A0), D0/D1/D2/D3/D4/D5/D6/D7 ; to do 8 consecutive reads very fast! but no it still increments A0, i believe.
