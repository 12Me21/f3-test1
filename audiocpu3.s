	CPU 68000
	SUPMODE ON
	PADDING ON
IS_AUDIO = 1
OVERRIDE_STDIN = 1
	ORG $0
	PHASE $C00000

	Include "duart-68000.s"
	Include "otis.s"
DUART_0 = $280000
OTIS_0 = $200000
DPRAM_0 = $140000
	
ESP_HALT = $26003F
parser_variables = $1500
	
VECTOR_USER_0 = $100

disable_interrupts	macro
	ori.w #$700, SR
	endm

enable_interrupts	macro
	andi.w #(~$700), SR
	endm
	

	
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
	
	jsr parser_reset
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

	IFDEF OVERRIDE_STDIN
	lea STDIN_0, A1
	jsr buffer_begin_write
	lea test_input, A0
	jsr buffer_push_string
	jsr buffer_end_write
	ENDIF
	
	jmp spin

test_input:	
	dc.b "$0t\ni$1s$600002 a rrrrrrrr\n", 0

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

	org $8000
b_tx_ready:	
	lea STDOUT_0, A1
	jsr buffer_begin_read
	jsr buffer_check_remaining
	beq .empy
.inner:
	jsr buffer_pop
	move.b D0, (A4, DUART_TBB)
	jsr buffer_check_remaining
	beq .empy
.ret:
	jsr buffer_end_read
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
	IFDEF OVERRIDE_STDIN
	rts
	ENDIF
	lea STDIN_0, A1
	jsr buffer_begin_write
	jsr buffer_push
	jsr buffer_end_write
	rts
		


setup_duart:
	move.l #user_0, VECTOR_USER_0
	
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
	
timer_ready:
	lea STDOUT_0, A1
	jsr buffer_begin_read
	jsr buffer_check_remaining
	beq .empy
	move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
	;btst.b #2, (DUART_0+DUART_SRB)
	;bne b_tx_ready.inner
.empy:
	jsr buffer_end_read

	jsr shared_do_commands
	rts
	
