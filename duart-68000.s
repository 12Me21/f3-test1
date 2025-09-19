;; for 68000, padded for 16-bit bus

DUART	Struct
	dc.b	?
	Union								  ; 0 (0)
MRA	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 1 (2)
SRA	dc.b	?
CSRA	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 2 (4)
CRA	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 3 (6)
RBA	dc.b	?
TBA	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 4 (8)
IPCR	dc.b	?
ACR	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 5 (a)
ISR	dc.b	?
IMR	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 6 (c)
CUR	dc.b	?
CTUR	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 7 (e)
CLR	dc.b	?
CTLR	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 8 (10)
MRB	dc.b	?
	Endunion
	dc.b	?
	Union								  ; 9 (12)
SRB	dc.b	?
CSRB	dc.b	?
	Endunion
	dc.b	?
	Union								  ; A (14)
CRB	dc.b	?
	Endunion
	dc.b	?
	Union								  ; B (16)
RBB	dc.b	?
TBB	dc.b	?
	Endunion
	dc.b	?
	Union								  ; C (18)
IVR	dc.b	?
	Endunion
	dc.b	?
	Union								  ; D (1a)
INPUT	dc.b	?
OPCR	dc.b	?
	Endunion
	dc.b	?
	Union								  ; E (1c)
START_C	dc.b	?
OPR_SET	dc.b	?
	Endunion
	dc.b	?
	Union								  ; F (1e)
STOP_C	dc.b	?
OPR_RES	dc.b	?
	Endunion
DUART	Endstruct
	
DUART_CR_ENABLE_RX = $01
DUART_CR_DISABLE_RX = $02
DUART_CR_ENABLE_TX = $04
DUART_CR_DISABLE_TX = $08
DUART_CR_RESET_MR = $10
DUART_CR_RESET_RX = $20
DUART_CR_RESET_TX = $30
DUART_CR_RESET_ERR = $40
DUART_CR_RESET_BCI = $50
DUART_CR_START_BRK = $60
DUART_CR_STOP_BRK = $70

DUART_MR1_8BIT = $03
DUART_MR1_NO_PAR = $10
