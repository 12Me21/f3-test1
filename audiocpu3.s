	CPU 68000
	SUPMODE ON
	PADDING ON
IS_AUDIO = 1
	ORG $0
	PHASE $C00000

	Include "duart-68000.s"
	Include "otis.s"
DUART_0 = $280000
OTIS_0 = $200000
DPRAM_0 = $140000
	
ESP_HALT = $26003F
parser_state = $1500
parser_next = parser_state+4 	  ;eventually this is gonna have to be a stack tbh
parser_acc = parser_next+4
parser_acc_len = parser_acc+4
	
VECTOR_USER_0 = $100

disable_interrupts	macro
	ori.w #$700, SR
	endm

enable_interrupts	macro
	andi.w #(~$700), SR
	endm

	;; this can't use .size notation because ATTRIBUTE can't be used in IF!
	;; anyway this is for 68000 where we don't have as many fancy addressing modes
	;; maybe there is a better way to do this but whatever
	;; before: [uuuu uuuu uuuu uuuu iiii iiii iiii iiii] i = index
	;; after:  [uuuu uuuu uuuu uuuu ???? ???? dddd dddd] d = data loaded from rom
	;; corrupts the second lowest byte, but leaves the upper word untouched
	;; note that the corrupted bits depend on the distance and direction to the data;
load_rel_b MACRO data, register
	addi.w #(data-(.testz+2)), register
.testz:
	move.b (PC, register), register
	ENDM
	

	
	Org $0
ROM_VECTORS_0:
	dc.l $000000
	dc.l (entry - $C00000)
	dc.l  [64-2]exc
;	Org $28
;	dc.l Line_a
	org $100
	dc.l exc
	;;  todo

	Org $400
	
spin:	
	stop #$2000
	bra spin
	
idle:	
	nop
	nop
	nop
	subq.l #1, D3
	bne idle
	rts

exc:	
	rte

	Include "shared-ram.s"
	
	;; note uses like, A1, A0, D0
puts_imm macro str
	lea .string, A2
	pea .next
	bra puts
.string:
	dc.b str, "\0"
	align 2
.next:
	endm
	
entry:
	movea.l ROM_VECTORS_0, SP
	
	moveq.l #76, D1
	lea ROM_VECTORS_0, A1
	lea 0, A0
.write_vectors:
	move.l (A1)+, (A0)+
	dbf D1, .write_vectors
	
	bsr setup_duart
	bsr setup_otis
	bsr setup_esp
	
	puts_imm "Hi!"
	move.w D2, D0
	bsr Byte_to_ascii_hex
	swap D0
	bsr putc
	swap D0
	bsr putc
	puts_imm "\n"
	
	jmp spin
	
user_0:	
	movem.l A5/A4/A2/A1/A0/D5/D3/D2/D1/D0, -(SP)
	clr.l D0
	lea DUART_0, A4
	move.b (A4, DUART_ISR), D0
	btst #5, D0
	beq .n1
	bsr b_rx_ready
.n1:
	btst #3, D0 					  ; 
	beq .n2
	tst.b (A4, DUART_STOP_C) ; acknowledge interrupt
	bsr timer_ready
.n2:
	btst #4, D0
	beq .n3
	bsr b_tx_ready
.n3:
	movem.l (SP)+, A5/A4/A2/A1/A0/D5/D3/D2/D1/D0
	rte

b_tx_ready:	
	jsr stdout_begin
	jsr shared_check_remaining
	beq .empy
	jsr shared_pop
	move.b D0, (A4, DUART_TBB)
	jsr shared_check_remaining
	beq .empy
.ret:
	jsr stdout_end
	rts
.empy:
	move.b #DUART_CR_DISABLE_TX, (A4, DUART_CRB)
	bra .ret

b_rx_ready:	
	move.b (A4, DUART_SRB), D1
	and.b #$50, D1
	beq.b .framing_and_overrun_ok
	bsr setup_duart
	puts_imm "Bad"
	rts
.framing_and_overrun_ok:
	clr.l D0
	move.b (A4, DUART_RBB), D5
	move.b D5, D0
	jsr stdin_begin
	jsr shared_push
	jsr stdin_end
	rts								  ;nevermind
parser_retry:
	move.l parser_state, A0
	jmp (A0)
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
	move.b #'~', D0
	bsr putc
	
	rts
	
	;; in: D0
	;; out: D0, flags
hex_char_to_ascii:	
	load_rel_b .HEX_TABLE, D0
	rts
.HEX_TABLE:	
	dc.b [48]-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, [7]-1, 10, 11, 12, 13, 14, 15, [26]-1, 10, 11, 12, 13, 14, 15, [25]-1, [128]-1
	Align 2
	
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
	puts_imm "bad addr."
	move.b parser_acc+3, D0
	bsr Byte_to_ascii_hex
	swap D0
	bsr putc
	swap D0
	bsr putc
	puts_imm "\n"
	
	move.l #ps_default, parser_state
	bra parser_retry
	rts
	
	;; D0 -> D0
	;; convert a byte into 2 ascii hex digits (unpacked)
Byte_to_ascii_hex:	
	;; [0000 0000 0000 0000 0000 0000 hhhh llll]
	ror.l #4, D0
	;; [llll 0000 0000 0000 0000 0000 0000 hhhh]
	;; work on the upper half
	load_rel_b .digits, D0
	;; [llll 0000 0000 0000 ???? ???? HHHH HHHH]
	;; now:
	swap D0
	;; [???? ???? HHHH HHHH llll 0000 0000 0000]
	rol.w #4, D0
	;; [???? ???? HHHH HHHH 0000 0000 0000 llll]
	load_rel_b .digits, D0
	;; [???? ???? HHHH HHHH ???? ???? LLLL LLLL]
	rts
	;; note in this case the garbage bits will be zeros, because the data is located
	;; _after_ the code, and fewer than 256 bytes away
.digits:
	dc.b "0123456789ABCDEFG"
	
ps_command_p:
	move.l #ps_default, parser_state
	
	puts_imm "READ:"
	
	move.b #'@', D0
	bsr putc
	
	clr.l D0
	move.b parser_acc+1, D0
	bsr Byte_to_ascii_hex
	swap D0
	bsr putc
	swap D0
	bsr putc
	
	clr.l D0
	move.b parser_acc+2, D0
	bsr Byte_to_ascii_hex
	swap D0
	bsr putc
	swap D0
	bsr putc

	clr.l D0
	move.b parser_acc+3, D0
	bsr Byte_to_ascii_hex
	swap D0
	bsr putc
	swap D0
	bsr putc

	move.b #'=', D0
	bsr putc

	move.l parser_acc, A0
	clr.l D0
	move.b (A0), D0
	bsr Byte_to_ascii_hex
	swap D0
	bsr putc
	swap D0
	bsr putc
	
	move.b #'\n', D0
	bsr putc
	
	rts

ps_command_w:
	move.l #ps_default, parser_state
	
	move.b #'w', D0
	bsr putc
	
	move.l parser_acc, D0
	move.b D0, D1
	lsr.l #8, D0
	move.l D0, A0
	move.b D1, (A0)
	
	move.b #'/', D0
	bsr putc
	move.b #'\n', D0
	bsr putc
	rts



setup_duart:
	move.l #user_0, VECTOR_USER_0
	move.l #ps_default, parser_state
	
	lea DUART_0, A4
	move.b #(VECTOR_USER_0/4), (A4, DUART_IVR) ; set interrupt vector number
	;; set up channel B 
	move.b #DUART_CR_RESET_RX, (A4, DUART_CRB)
	move.b #DUART_CR_RESET_TX, (A4, DUART_CRB)
	move.b #DUART_CR_RESET_ERR, (A4, DUART_CRB)
	move.b #DUART_CR_RESET_BCI, (A4, DUART_CRB)
	
	move.b #DUART_CR_RESET_MR, (A4, DUART_CRB)
	;; program channel B for 62500 baud 8N1
	move.b #$13, (A4, DUART_MRB) ; - 8bit, no parity, error mode = char, Rx IRQ = RxRDY, Rx RTS off 
	move.b #$07, (A4, DUART_MRB) ; - stop bit length = 1.0, CTS off, Tx RTS off, channel mode normal
	move.b #$EE, (A4, DUART_CSRB); - baud rate: TX = IP5 16X, RX = IP2 16X (IP2/5 are 1MHz -> 62500 baud)
	move.b #(DUART_CR_ENABLE_RX | DUART_CR_ENABLE_TX), (A4, DUART_CRB)
	
	;; set up timer
	move.w #2500, D0 				  ; will be 4MHz / 2500 = 1600Hz
	movep.w D0, (A4, DUART_CTUR)
	move.b #$60, (A4, DUART_ACR) ; Timer mode, use external clock (4MHz)
	;; enable interrupts: RxRDYB and counter
	move.b #(DUART_IMR_RX_B | DUART_IMR_TX_B | DUART_IMR_COUNTER), (A4, DUART_IMR)
	
	rts
	
setup_otis:	
	lea OTIS_0, A4
	move.w #64, (A4, OTIS_PAGE)
	move.w #$0000, (A4, OTIS_R8) ; SERMODE = 0
	move.w #(32-1), D7 ; 32 voices
	move.w D7, (A4, OTIS_ACT) 	  ; yeah -1
.loop_voices:
	move.w D7, (A4, OTIS_PAGE)
	move.l A4, A2
	lea .DATA, A1
	move.w (A1)+, D0
	;; first one differs for voice 0
	cmp.w #0, D7
	bne .not_voice_0
	bclr #2, D0
	bra .endif
.not_voice_0:
	bset #2, D0
.endif:
	move.w D0, (A2)+
	move.w #$A, D0
.loop_B:
	move.w (A1)+, (A2)+
	dbf D0, .loop_B
	dbf D7, .loop_voices
	;; irq something?
	;; can we even get interrupts from the otis?
	;; i cant see what code would handle that, we have user int 0, which only does duart
	;; and then everything else is an unexpected event
	move.w (A4, OTIS_IRQV), D0
	move.w #$A0, D0
.delay:
	dbf D0, .delay
	move.w (A4, OTIS_IRQV), D0
	;; [sometimes here we set ACT to 0x14]
	rts
.DATA:
	dc.w $0C07, $0800
	dc.l -513
	dc.l -513
	dc.w -1, -1
	dc.w 0, 0
	dc.l -513

setup_esp:
	;; ok so this clears OPR[6], which is connected to pal8.3
	;; but do we ever actually SET it? there is a function to do so but idk if/when it's called
	;; also idk what it does
	move.b #$40, DUART_0+DUART_OPR_RES
	
	move.b #2, ESP_HALT
	rts
	
	org $8000
timer_ready:	
	;; check if we have any data to re-enable tx for (in case it was written by main cpu)
	move.l STDOUT_READ, D0 		  ; fast way to read STDOUT_READ and _WRITE
	move.b D0, D1
	swap D0
	cmp.w D0, D1
	beq .empy
	move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
.empy:
	rts
	
	;; takes D0
putc:
	movem.l	A0/A1/D0/D7, -(SP)
	jsr stdout_begin
	jsr shared_push
	jsr stdout_end
	move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
	movem.l	(SP)+, A0/A1/D0/D7
	rts
	
	;; takes A2
puts:
	movem.l	A0/A1/D0/D7, -(SP)	
	jsr stdout_begin
.loop:
	move.b (A2)+, D0
	beq .exit
	jsr shared_push
	bra .loop
.exit:
	jsr stdout_end
	move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
	movem.l	(SP)+, A0/A1/D0/D7
	rts
