		CPU 68000
		SUPMODE ON
		PADDING ON
		ORG $C00000

Include "duart-68000.s"
	
ROM_VECTORS_0:
	dc.l	$00000000
	dc.l	entry
	dc.l  [75]exc
	
spin:	
	move.b #12, $140000
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
	
	jmp spin
	
	
