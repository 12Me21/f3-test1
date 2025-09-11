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

duart_jump_on_recv_A = $D900
duart_D904 = $D904
duart_D906 = $D906
duart_D90C = $D90C
duart_D90E = $D90E
duart_D90F = $D90F
duart_FB12 = $FB12		;byte array
duart_FB14 = $FB14 		; hm


	
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
	move.l #user_int0.finish_user_int0, duart_jump_on_recv_A
	move.l #user_int0.finish_user_int0, duart_jump_on_recv_B

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
	;; check ISR
	move.b (A4, DUART_ISR), D0
	move.b D0, D1
	btst.l #5, D0
	bne .b_rx_ready
	and.b #$06, D1
	bne .a_rx_ready_or_delta_break_a
	btst.l #0, D0
	bne .a_tx_ready
	btst.l #3, D0
	bne .timer_ready
	move.w #$FF91, D0
	;trap #0 		; triggers a reset ? why
	rte
.finish_user_int0:
	movem.l (SP)+, A5/A4/A2/A1/A0/D3/D2/D1/D0
	rte
.b_rx_ready:
	move.b (A4, DUART_SRB), D1
	and.b #$50, D1
	beq.b .framing_and_overrun_ok
	;; got framing error or overrun error, reset?
	bsr duart_40c
	bra .finish_user_int0
.framing_and_overrun_ok:
	moveq #0, D1
	moveq #0, D2
	move.b (A4, DUART_RBB), D1
	bsr duart_45c
	lea duart_jump_on_recv_B, A0
	moveq #0, D0
	jmp (A0)
.a_rx_ready_or_delta_break_a:
	and.b #$04, D1 		; why not btst..
	bne .didnt_a		;if delta break
	move.b (A4, DUART_SRA), D0
	beq .didnt_a		;if status bits all 0
	and.b #$F0, D0
	beq .no_errors_a
.didnt_a:
	tas duart_D90F
	bne .d90f_ne
	;trap #3 		; get linked list head into A5 and do other things
	;move.w #$4, (A5, 2) 	; write data to something in linked list
	;move.w #$fb54, A1
	;trap #9 		; do something with A5 and A1 linked list related
.d90f_ne:
	bsr duart_130c
	bra .finish_user_int0
.no_errors_a:
	moveq #0, D1
	move.b (A4, DUART_RBA), D1
	bmi .rx_a_minus
	;; if [0... ....] - do normal thing
	movea.l duart_jump_on_recv_A, A0
	jmp (A0)
.rx_a_minus: 	
	; matches [1... ....]
	clr.b duart_D90F
	move.w D1, D2
	and.w #$70, D1
	cmp.b #$70, D1
	beq.w .rx_a_F0 		; jump if matches [1111 ....]
	;; otherwise: 
	move.w D2, D1
	and.w #$0F, D1
	move.w D1, duart_D906
	move.b $CF5C, D0
	clr.b duart_D90E
	cmp.b #0, D0
	bne .cf5c_nonzero
	clr.w duart_D904
	bra .later
.cf5c_nonzero:
	cmp.b #1, D0
	bne .cf5c_not_1
	cmp.b $CF5A, D1
	bne .duart_12fe
	clr.w duart_D904
	bra.b .later
.cf5c_not_1:
	cmp.b #2, D0
	bne .cf5c_not_2
.loop3:
	;; [check struct things]
	;bne duart_12fe
	move.w D0, duart_D904
	bra .later
.cf5c_not_2:	
	sub.b $C5FA, D1
	and.b #$F, D1
	cmp.b #$F, D1
	bne .a
	move.b D1, duart_D90E
	bra .later
.a:
	cmp.b #3, D0
	bne .cf5c_not_3
	cmp.b #$8, D1
	bcc .duart_12fe
	move.w D1, duart_D904
	bra .later
.cf5c_not_3:
	add.b $CF5A, D1
	and.b #$F, D1
	bra .loop3
.later:
	and.w #$70, D2 		; extract: [1xxx ....] - set state to x in table 1 (note; won't be state 7)
	lsr.w #2, D2
	lea .rx_a_80_states, A0
	move.l (0, A0, D2*1), (duart_jump_on_recv_A)
	bra.w .finish_user_int0
.rx_a_F0: 			; byte matched [1111 xxxx] - jump to behavior x in table 2 immediately
	move.w D2, D1
	and.w #$F, D2
	lsl.w #2, D2
	lea .rx_a_F0_actions, A0
	lea (0, A0, D2*1), A0
	jmp (A0)
.a_tx_ready:
	;lea $D8FC, A5
	;trap #4
	;lea $fb96, A1
	;jsr c10cf6  does a bunch of things with A1 but thats it
	;bcc .cc
	move.b #$08, (A4, DUART_IMR) ; enable interrupts: timer ready
.cc:
	;move.w A5, $D8FC
	bra.w .finish_user_int0
.timer_ready:
	tst.b (A4, DUART_STOP_C) ; stop counter
	;; dont care
	;lea duart_FB12, A0
	;move.w #0, D0
;.loop2:
	;move.w 
	;; etc etc
	bsr duart_send_1_from_buffer
	;; etc
	bra .finish_user_int0
.duart_12fe:	
	bsr .duart_1304
	bra .finish_user_int0
.duart_1304:	
	move.l (SP)+, duart_jump_on_recv_A
	bra .finish_user_int0
.rx_a_80_states:
.rx_a_F0_actions:

duart_1318:
	move.l #user_int0.duart_12fe, duart_jump_on_recv_A
	rts
duart_130c:	
	move.w #$FF, duart_D90C
	bsr duart_1318
	bsr duart_e86
	rts

duart_40c:	
	bsr duart_45c
	move.b #$94, D0
	bsr duart_send_1
	move.b #$FF, D0
	bsr duart_send_1
	move.l #16666, D3
	bsr idle
	bsr duart_eac
	move.l #duart_process_b, duart_jump_on_recv_B
	bsr duart_45c
	rts
	
duart_process_b:
	;; ...
	bra.w user_int0.finish_user_int0

duart_45c:	
	lea DUART_0, A4
	move.b #$80, D0 	; flash  OPR7
	move.b D0, (A4, DUART_OPR_RES)
	move.b D0, (A4, DUART_OPR_SET)
	move.b D0, (A4, DUART_OPR_RES)
	rts

duart_e22:	
	lea DUART_0, A4
	move.b #$00, (A4, DUART_IMR) ; disable interrupts
	bsr duart_e86
	
	;; configure channel A:
	move.b #$10, (A4, DUART_CRA) ; COMMAND: reset MRA pointer
	move.b #$13, (A4, DUART_MRA) ; - 8bit, no parity, error mode = char, Rx IRQ = RxRDY, Rx RTS off
	move.b #$07, (A4, DUART_MRA) ; - stop bit length = 1.0, CTS off, Tx RTS off, channel mode normal
	move.b #$EE, (A4, DUART_CSRA); - baud rate: TX = IP3 16X, RX = IP4 16X (IP3/4 are 0.5mhz -> 31250 baud i think)
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
	move.b #$EE, (A4, DUART_CSRB); - baud rate: TX = IP5 16X, RX = IP2 16X (IP2/5 are 1mhz -> 62500 baud)
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
	bsr duart_130c
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
	bsr duart_40c
	bsr duart_11a6
.ret:
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
	
data_C0818A:
	dc.b $02, $02, $02, $02, $02, $0e, $12, $0c
	;; 00000010
	;; 00000010
	;; 00000010
	;; 00000010
	;; 00000010
	;; 00001110
	;; 00010010
	;; 00001100
	;; send 93, 0C, 8 bytes, 81, 83
duart_11a6:
	move.b #$93, D0
	bsr duart_send_1
	move.b #$0C, D0
	bsr duart_send_1
	lea data_C0818A, A1
	moveq.l #0, D1
.loop:
	move.b (0, A1, D1*1), D0
	bsr duart_send_1
	add.w #1, D1
	cmp.w #8, D1
	bne .loop
	move.b #$81, D0
	bsr duart_send_1
	;; maybe address here
	move.b #$83, D0
	bsr duart_send_1
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
	bclr.b #1, duart_FB14
	bra .send_buffer_empty
.send_buffer_not_empty:
	bra .ret
.send_buffer_empty:
	move.b #$08, (A4, DUART_CRB) ; CND: transmitter disabled
.ret:
	rts

idle:	
	nop
	nop
	nop
	subq.l #1, D3
	bne idle
	rts
