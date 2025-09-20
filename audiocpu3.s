	CPU 68000
	SUPMODE ON
	PADDING ON
	ORG $C00000

	Include "duart-68000.s"
	Include "otis.s"
DUART_0 = $280000
OTIS_0 = $200000
DPRAM_0 = $140000
ESP_HALT = $26003F
spin_pointer = $1000
parser_state = $1500

VECTOR_USER_0 = $100


disable_interrupts	macro
	ori.w #$700, SR
	endm

enable_interrupts	macro
	andi.w #(~$700), SR
	endm


	
	Org $C00000
ROM_VECTORS_0:
	dc.l $000000
	dc.l entry
	dc.l  [64-2]exc
;	Org $C00028
;	dc.l Line_a
	org $C00100
	dc.l exc
	;;  todo

	Org $C00400
	
spin:	
	stop #$2000
	bra spin

exc:	
	rte
	
	
entry:	
	moveq.l #$7F, D0
	move.l D0, D1
	neg.l D1
.wait:
	suba.l A1, A1
	move.l D0, (A1)+
	move.l D1, (A1)
	cmp.l (A1), D1
	bne .check1_fail
	cmp.l -(A1), D0
.check1_fail:
	bne .wait
	
	movea.l ROM_VECTORS_0, SP
	
	moveq.l #76, D1
	lea ROM_VECTORS_0, A1
	lea 0, A0
.write_vectors:
	move.l (A1)+, (A0)+
	dbf D1, .write_vectors
	
	move.b #12, DPRAM_0
	
	jsr buffer_setup
	jsr setup_duart
	jsr setup_otis
	jsr setup_esp
	
	move.b #'H', D0
	jsr buffer_push_1
	move.b #'i', D0
	jsr buffer_push_1
	move.b #'!', D0
	jsr buffer_push_1

	jmp spin
	
user_0:	
	movem.l A5/A4/A2/A1/A0/D3/D2/D1/D0, -(SP)
	lea DUART_0, A4
	move.b (A4, DUART_ISR), D0
	btst #5, D0
	beq .n1
	jsr b_rx_ready
.n1:
	btst #3, D0 					  ; 
	beq .n2
	tst.b (A4, DUART_STOP_C) ; acknowledge interrupt
	jsr timer_ready
.n2:
	movem.l (SP)+, A5/A4/A2/A1/A0/D3/D2/D1/D0
	rte

b_rx_ready:	
	move.b (A4, DUART_SRB), D1
	and.b #$50, D1
	beq.b .framing_and_overrun_ok
	jsr setup_duart
	rts
.framing_and_overrun_ok:
	move.b (A4, DUART_RBB), D0
	move.l parser_state, A0
	jmp (A0)
	rts
	
parser_default:
	move.l spin_pointer, A1
	move.b D0, (A1)
	adda.w #2, A1
	move.l A1, spin_pointer
	andi.w #$1FF, (spin_pointer+2)
	move.w (spin_pointer+2), D0
	move.b D0, (DPRAM_0+256*2)
	rts

setup_duart:
	move.l #user_0, VECTOR_USER_0
	move.l #DPRAM_0, spin_pointer
	move.l #parser_default, parser_state
	
	lea DUART_0, A4
	move.b #(VECTOR_USER_0/4), (A4, DUART_IVR) ; set interrupt vector number
	;; set up channel B 
	move.b #DUART_CR_RESET_RX, (A4, DUART_CRB)
	move.b #DUART_CR_RESET_TX, (A4, DUART_CRB)
	move.b #DUART_CR_RESET_ERR, (A4, DUART_CRB)
	move.b #DUART_CR_RESET_BCI, (A4, DUART_CRB)
	
	move.b #DUART_CR_RESET_MR, (A4, DUART_CRB)
	move.b #$13, (A4, DUART_MRB) ; - 8bit, no parity, error mode = char, Rx IRQ = RxRDY, Rx RTS off 
	move.b #$0F, (A4, DUART_MRB) ; - stop bit length = 2.0, CTS off, Tx RTS off, channel mode normal
	move.b #$EE, (A4, DUART_CSRB); - baud rate: TX = IP5 16X, RX = IP2 16X (IP2/5 are 1mhz -> 62500 baud)
	move.b #(DUART_CR_ENABLE_RX | DUART_CR_ENABLE_TX), (A4, DUART_CRB)
	
	;; set up timer
	move.w #2500, D0
	movep.w D0, (A4, DUART_CTUR)
	move.b #$60, (A4, DUART_ACR) ; Timer mode, use external clock (4mhz)
	;; enable interrupts: RxRDYB and counter
	move.b #(DUART_IMR_RX_B | DUART_IMR_COUNTER), (A4, DUART_IMR)
	
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
	

buffer_start = $2000
buffer_end = buffer_start+100
buffer_read_ptr = buffer_end
buffer_write_ptr = buffer_end+2
buffer_filled = buffer_end+4
	
buffer_setup:	
	move.b #0, buffer_filled
	move.w #buffer_start, buffer_read_ptr
	move.w #buffer_start, buffer_write_ptr
	rts
	
	;; D0, A0
buffer_push:
	move.w buffer_write_ptr, A0
	move.b D0, (A0)+
	bsr buffer_wrap_a0
	move.w A0, buffer_write_ptr
	addq.b #1, buffer_filled
	rts
	
buffer_wrap_a0:	
	cmpa.w #buffer_end, A0
	bcs .ok
	move.w #buffer_start, A0
.ok:
	rts
	
	;; D0, A0
buffer_pop:	
	move.w buffer_read_ptr, A0
	move.b (A0)+, D0
	bsr buffer_wrap_a0
	move.w A0, buffer_read_ptr
	subq.b #1, buffer_filled
	rts
	
buffer_send_1:	
	lea DUART_0, A4
	tst.b buffer_filled
	beq .empy
	bsr buffer_pop
	move.b D0, (A4, DUART_TBB)
	tst.b buffer_filled
	beq .empy
	rts
.empy:
	move.b #DUART_CR_DISABLE_TX, (A4, DUART_CRB)
	rts
	
	;; D0
buffer_push_1:	
	lea DUART_0, A4
	bsr buffer_push
	move.b #DUART_CR_ENABLE_TX, (A4, DUART_CRB)
	rts
	
timer_ready:	
	jsr buffer_send_1
	rts
	
;todo:
DPRAM_SEND_BUFFER = DPRAM_0
DPRAM_RECV_BUFFER = DPRAM_0+$100
DPRAM_WRITE_PTR = DPRAM_0+$200
DPRAM_READ_PTR = DPRAM_0+$201
dpram_write_pointer = $1000
dpram_read_pointer = $1004

dpram_setup:	
	move.b $00, DPRAM_WRITE_PTR
	move.b $00, DPRAM_READ_PTR
	rts

	;; D0
dpram_send:	
	rts
