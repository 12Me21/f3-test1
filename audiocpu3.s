	CPU 68000
	SUPMODE ON
	PADDING ON
	ORG $C00000

	Include "duart-68000.s"
DUART_0 = $280000
OTIS_0 = $200000
	
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
	move.w #64, (A4, OTIS_R15)   ; page 64
	;; 
	move.w #$0000, (A4, OTIS_R8) ; SERMODE
	
	
