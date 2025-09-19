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

VECTOR_USER_0 = $0100
	
	Org $C00000
	dc.l  [64]exc
	Org $C00000
ROM_VECTORS_0:
	dc.l $000000
	dc.l entry
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
	
	movea.l (ROM_VECTORS_0), SP
	
	moveq.l #76, D1
	lea ROM_VECTORS_0, A1
	lea 0, A0
.write_vectors:
	move.l (A1)+, (A0)+
	dbf D1, .write_vectors
	
	move.b #12, $140000
	
	jsr setup_duart
	jsr setup_otis
	jsr setup_esp
	
	jmp spin
	
user_0:	
	movem.l A5/A4/A2/A1/A0/D3/D2/D1/D0, -(SP)
	lea DUART_0, A4
	move.b (A4, DUART_ISR), D0
	btst #5, D0
	beq .n1
	jsr b_rx_ready
.n1:
	movem.l (SP)+, A5/A4/A2/A1/A0/D3/D2/D1/D0
	rte

b_rx_ready:	
	move.b (A4, DUART_SRB), D1
	and.b #$50, D1
	beq.b .framing_and_overrun_ok
	jsr setup_duart
	rts
.framing_and_overrun_ok:
	moveq #0, D1
	move.b (A4, DUART_RBB), D1
	move.l spin_pointer, A1
	move.b D1, (A1)+
	move.l A1, spin_pointer
	rts
	
setup_duart:
	move.l #user_0, VECTOR_USER_0
	move.l #DPRAM_0, spin_pointer
	
	lea DUART_0, A4
	move.b #$40, (A4, DUART_IVR) ; idk why we set this, seems like we always just go to user interrupt 0?
	
	move.b #$20, (A4, DUART_CRB)	;CMD: reset reciever
	move.b #$30, (A4, DUART_CRB)	;CMD: reset transmitter
	move.b #$40, (A4, DUART_CRB)	;CMD: reset error status
	move.b #$50, (A4, DUART_CRB)	;CMD: reset break change interrupt
	
	move.b #$10, (A4, DUART_CRB)	;CMD: reset MRB pointer
	move.b #$13, (A4, DUART_MRB) ; - 8bit, no parity, error mode = char, Rx IRQ = RxRDY, Rx RTS off 
	move.b #$0F, (A4, DUART_MRB) ; - stop bit length = 2.0, CTS off, Tx RTS off, channel mode normal
	move.b #$EE, (A4, DUART_CSRB); - baud rate: TX = IP5 16X, RX = IP2 16X (IP2/5 are 1mhz -> 62500 baud)
	move.b #$05, (A4, DUART_CRB) ;CMD: transmitter enabled, reciever enabled
	
	move.b #(1<<5), (A4, DUART_IMR) ; enable interrupt RxRDY B
	
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
	;move.b #$40, DUART_0+DUART_OPR_RES
	
	move.b #2, ESP_HALT
	rts
