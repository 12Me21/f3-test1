	CPU 68000
	SUPMODE ON
	PADDING ON
	ORG $C00000

	Include "duart-68000.s"
	Include "otis.s"
DUART_0 = $280000
OTIS_0 = $200000
ESP_HALT = $26003F
	
	Org $C00000
	dc.l  [64]exc
	Org $C00000
ROM_VECTORS_0:
	dc.l $000000
	dc.l entry
;	Org $C00028
;	dc.l Line_a
	org $C00100
USER_INT_0:	
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
	move.w (A4, OTIS_IRQV), D0
	move.w #$A0, D0
.delay:
	dbf, D0, .delay
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

