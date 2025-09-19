		CPU 68000
		SUPMODE ON
		PADDING ON
		ORG $C00000

	Include "duart-68000.s"
DUART_0 = $280000
duart_jump_on_recv_B = $d518
duart_D528 = $D528
duart_D526 = $D526

send_buffer = $D684
send_buffer_end = $D6A4
send_buffer_write_ptr = $D6A4
send_buffer_read_ptr = $D6A6
send_buffer_length = $D6A8
	
move_D0_SR	Macro
	dc.w $A000
	Endm
	
	org $C00000
	dc.l  [64]exc
	org $C00000
ROM_VECTORS_0:
	dc.l $000000
	dc.l entry
	org $C00028
	dc.l Line_a
	org $C00100
USER_INT_0:	
	dc.l exc
	;;  todo

	org $C00400
spin:	
	;; [more FB12]
	stop #$2000
	bra spin

exc:	
	rte
	
trap_0:	
	
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
	
	jmp entry_duart
	
	

	
entry_duart:	
	move.l #user_int0.finish, duart_jump_on_recv_B

	move.l #.user_int0_first, (USER_INT_0 & $FFFF)
	
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
	bra .after
	
.user_int0_first:
	move.l #user_int0, (USER_INT_0 & $FFFF)
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ; disable interrupts
	tst.b (A4, DUART_STOP_C)     ; stop counter
	move.b #$60, (A4, DUART_ACR) ; Timer mode, use external clock (4mhz)
	;; also do otis stuff here
	rte
.after:
	
	clr.b duart_D528
	;; [check otis stuff]
	tas duart_D528 		;should be conditional on the otis check
	bsr duart_f26
	;; [stuff with FB12 etc]
	jmp spin
		
user_int0:	
	movem.l A5/A4/A2/A1/A0/D3/D2/D1/D0, -(SP)
	lea DUART_0, A4
	;; check interrupt status
	move.b (A4, DUART_ISR), D0
	btst #5, D0
	bne .b_rx_ready
	btst #3, D0
	bne .timer_ready
	;; otherwise, bad interrupt
	move.w #$91, D0
	trap #0
	rte
.finish:
	movem.l (SP)+, A5/A4/A2/A1/A0/D3/D2/D1/D0
	rte
.b_rx_ready:
	move.b (A4, DUART_SRB), D1
	and.b #$50, D1
	beq.b .framing_and_overrun_ok
	;; got framing error or overrun error, reset?
	bsr duart_40c_reset_b
	bra .finish
.framing_and_overrun_ok:
	moveq #0, D1
	moveq #0, D2
	move.b (A4, DUART_RBB), D1
	bsr duart_45c_flash_op7
	lea duart_jump_on_recv_B, A0
	moveq #0, D0
	jmp (A0)
.timer_ready:
	tst.b (A4, DUART_STOP_C) ; stop counter (do we ever restart it?)
	bsr duart_send_1_from_buffer
	;; etc
	bra .finish

duart_40c_reset_b:	
	bsr duart_45c_flash_op7
	move.b #$94, D0
	bsr duart_send_1
	move.b #$FF, D0
	bsr duart_send_1
	move.l #16666, D3
	bsr idle
	bsr duart_eac_setup_b
	move.l #duart_process_b, duart_jump_on_recv_B
	bsr duart_45c_flash_op7
	rts
	
duart_process_b:
	;; ...
	bra.w user_int0.finish

duart_45c_flash_op7:	
	lea DUART_0, A4
	move.b #$80, D0 	; flash  OPR7
	move.b D0, (A4, DUART_OPR_RES)
	move.b D0, (A4, DUART_OPR_SET)
	move.b D0, (A4, DUART_OPR_RES)
	rts

duart_e22:	
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ; disable interrupts
	
	;; set up counter again (0.000625 seconds or 0.0005 seconds)
	move.w #2500, D0	; set counter register to 2500 or 2000
	tst.b duart_D528
	;beq.b .n1
	move.w #2000, D0
.n1:
	movep.w D0, (A4, DUART_CTUR)
	move.b #$60, (A4, DUART_ACR) ; Timer mode, use external clock (4mhz)
	bsr duart_e74_enable_interrupts
	rts
	
duart_e74_enable_interrupts:
	lea DUART_0, A4
	move.b #$2B, (A4, DUART_IMR) ; enable interrupts: TxRDYA, RxRDYA, timer ready, RxRDYB
	rts
	
duart_eac_setup_b:
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
	move.b #$EE, (A4, DUART_CSRB); - baud rate: TX = IP5 16X, RX = IP2 16X (IP2/5 are 1mhz -> 62500 baud)
	move.b #$05, (A4, DUART_CRB) ;CMD: transmitter enabled, reciever enabled
	rts
	
duart_f26:
	tst.b duart_D526
	bne .ne
	;; D is 0
	bsr duart_e22
.ne:
	bsr duart_f60_safe_disable_interrupts
	tst.b duart_D526
	bne .ret
	bsr duart_eac_setup_b
	bsr send_buffer_reset
	bsr duart_40c_reset_b
	;; we know this function is init probably
.ret:
	bsr duart_e74_enable_interrupts
	clr.b duart_D526
	rts
	
duart_f60_safe_disable_interrupts:
	move.w	SR, D7
	move.w #$0500, D0	; interrupt mask: 5
	move_D0_SR
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ;disable interrupts
	move.w D7, D0		; restore SR
	move_D0_SR
	rts
	
send_buffer_reset:
	move.w #send_buffer, send_buffer_write_ptr
	move.w #send_buffer, send_buffer_read_ptr
	clr.b send_buffer_length
	move.l #166666, D3
	bsr idle
	move.b #$80, D0
	bsr duart_send_1
	move.l #8000, D3
	bsr idle
	rts

duart_send_1:	
	lea DUART_0, A4
	;; channel B:
	move.b #$04, (A4, DUART_CRB) ; CMD: transmitter enabled
	move.b D0, (A4, DUART_TBB)   ; push byte to transmit buffer
.wait_for_txready:
	btst.b #3, (A4, DUART_SRB)   ; check status, TxRDY
	beq .wait_for_txready
	move.b #$08, (A4, DUART_CRB) ; CMD: transmitter disabled
	rts
	
duart_send_1_from_buffer:	
	tst.b send_buffer_length
	beq .send_buffer_empty
	move.w send_buffer_read_ptr, A0
	move.b (A0)+, (A4, DUART_TBB)
	cmpa #send_buffer_end, A0
	bcs .not_wrap
	lea send_buffer, A0
.not_wrap:
	move.w A0, send_buffer_read_ptr
	subq.b #1, send_buffer_length
	bne .send_buffer_not_empty
.send_buffer_empty:
	move.b #$08, (A4, DUART_CRB) ; CMD: transmitter disabled
	rts
.send_buffer_not_empty:
	rts

idle:	
	nop
	nop
	nop
	subq.l #1, D3
	bne idle
	rts
	
write_to_send_buffer:	
	ori #$0700, SR
	cmpi.b #$20, send_buffer_length
										  ;bcs 
	rts
