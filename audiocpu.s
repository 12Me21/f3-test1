		CPU 68000
		SUPMODE ON
		PADDING ON
		ORG $C00000

Include "duart-68000.s"
DUART_0 = $280000
duart_D528 = $D528 		;variable
duart_D526 = $D526 		;variable	

move_D0_SR	Macro
	dc.w $A000
	Endm
	
ROM_VECTORS_0:
	dc.l	$00000000
	dc.l	entry
	dc.l  [62]exc
	org $C00100
USER_INT_0:	
	dc.l exc
	
	org $C00400
	dc.l Line_a
	
	org $C00400
spin:	
	move.b #12, $140000
	bra spin

exc:	
	rte
	
	;; hack to set SR on the 68000
Line_a:	
	move.w D0, (SP)		; override status register
	addq.l #2, (SP, 2) 	; bump return address
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
	
	jmp spin
	
	

	
entry_duart:	
	move.l #.user_int0_first, USER_INT_0
	
	lea DUART_0, A4
	move.b #$40, (A4, DUART_IVR) ; idk why we set this, seems like we always just go to user interrupt 0?
	;; set up a 0.01-second counter: (idk if this repeats, i think it does?)
	move.w #2500, D0	     ; set counter register to 2500
	movep.w D0, (A4, DUART_CTUR)
	move.b #$30, (A4, DUART_ACR) ; Counter mode, use external clock (4mhz) divded by 16
	tst.b (A4, DUART_START_C)    ; start the counter
	move.b #$08, (A4, DUART_IMR) ; enable counter ready interrupt only
	
	stop #$2000 		; wait for interrupt
	ori #$700, SR		; disable interrupts
	
	clr.b duart_D528
	;; [check otis stuff]
	tas duart_D528 		;should be conditional on the otis check
	bsr duart_f26
	
.user_int0_first:
	move.l #user_int0_after, USER_INT_0
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ; disable interrupts
	tst.b (A4, DUART_STOP_C)     ; stop counter
	move.b #$60, (A4, DUART_ACR) ; Timer mode, use external clock (4mhz)
	;; also do otis stuff here
	rte
	
user_int0_after:	
	
	rte
	
duart_e22:	
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ; disable interrupts
	bsr duart_e86
	
	;; configure channel A:
	move.b #$10, (A4, DUART_CRA) ; COMMAND: reset MRA pointer
	move.b #$13, (A4, DUART_MRA) ; - 8bit, no parity, error mode = char, Rx IRQ = RxRDY, Rx RTS off
	move.b #$07, (A4, DUART_MRA) ; - stop bit length = 1.0, CTS off, Tx RTS off, channel mode normal
	move.b #$EE, (A4, DUART_CSRA); - baud rate: TX = IP3 16X, RX = IP3 16X (IP3 is 0.5mhz -> 31250 baud i think)
	move.b #$01, (A4, DUART_CRA) ; COMMAND: reciever enabled
	move.b #$30, (A4, DUART_CRA) ; COMMAND: reset transmitter
	move.b #$08, (A4, DUART_CRA) ; COMMAND: transmitter disabled
	
	move.b #$40, (A4, DUART_IVR) ; interrupt vector 40 (does this do anything?)
	
	;; set up counter again (0.000625 seconds or 0.0005 seconds)
	move.w #2500, D0	; set counter register to 2500 or 2000
	tst.b duart_D528
	;beq.b .n1
	move.w #2000, D0
.n1:
	movep.w D0, (A4, DUART_CTUR)
	move.b #$60, (A4, DUART_ACR) ; Timer mode, use external clock (4mhz)
	;; FALLTHROUGH
duart_e74:
	lea DUART_0, A4
	move.b #$2B, (A4, DUART_IMR) ; enable interrupts: TxRDYA, RxRDYA, timer ready, RxRDYB
	rts
	
duart_e86:
	lea DUART_0, A4
	;; channel A things
	move.b (A4, DUART_SRA), D0   ; read channel A status
	move.b #$40, (A4, DUART_CRA) ; COMMAND: reset error status
	move.b #$50, (A4, DUART_CRA) ; COMMAND: reset break change interrupt
	btst.l #7, D0		     ; check bit: Recieved Break
	bne .recieved_break
	move.b #$20, (A4, DUART_CRA) ; COMMAND: reset reciever
	move.b #$01, (A4, DUART_CRA) ; COMMAND: reciever enabled
.recieved_break:
	rts
	
duart_eac:
	;; channel B:
	lea DUART_0, A4
	lea (A4, DUART_CRB), A0
	move.b #$20, (A0)	;CMD: reset reciever
	move.b #$30, (A0)	;CMD: reset transmitter
	move.b #$40, (A0)	;CMD: reset error status
	move.b #$50, (A0)	;CMD: reset break change interrupt
	;; write mode registers
	move.b #$10, (A0)	;CMD: reset MRB pointer
	move.b #$13, (A4, DUART_MRB) ; - 8bit, no parity, error mode = char, Rx IRQ = RxRDY, Rx RTS off 
	move.b #$0F, (A4, DUART_MRB) ; - stop bit length = 2.0, CTS off, Tx RTS off, channel mode normal
duart_ed4:			     ;maybe fake label
	move.b #$EE, (A4, DUART_CSRB); - baud rate: TX = IP3 16X, RX = IP3 16X (IP3 is 0.5mhz -> 31250 baud i think)
	move.b #$05, (A4, DUART_CRB) ;CMD: transmitter enabled, reciever enabled
	rts
	
duart_f26:
	lea $D680, A0
	;; bunch of stack things. this is similar to LINK
	move.l	SP, -(A0)
	move.l	A0, SP
	movem.l A6/A5/A4/A3/A2/A1/D7/D6/D5/D4/D3/D2/D1/D0, -(SP)
	tst.b duart_D526
	bne .ne
	bsr duart_e22
.ne:
	bsr duart_f60
	bsr duart_1026
	...
	rts
	
duart_f60:
	move.w	SR, D7
	move.w #$0500, D0	; interrupt mask: 5
	move_D0_SR
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ;disable interrupts
	move.w D7, D0		; restore SR
	move_D0_SR
	rts
	
duart_1026:	
	tst.b duart_D526
	bne .ret
	bsr duart_eac
	bsr send_buffer_reset
.ret:
	rts
