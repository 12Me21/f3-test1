;; for 68000, padded for 16-bit bus

DUART	Struct
	dc.b	?
	Union
MRA	dc.b	?
	Endunion
	dc.b	?
	Union
SRA	dc.b	?
CSRA	dc.b	?
	Endunion
	dc.b	?
	Union
CRA	dc.b	?
	Endunion
	dc.b	?
	Union
RBA	dc.b	?
TBA	dc.b	?
	Endunion
	dc.b	?
	Union
IPCR	dc.b	?
ACR	dc.b	?
	Endunion
	dc.b	?
	Union
ISR	dc.b	?
IMR	dc.b	?
	Endunion
	dc.b	?
	Union
CUR	dc.b	?
CTUR	dc.b	?
	Endunion
	dc.b	?
	Union
CLR	dc.b	?
CTLR	dc.b	?
	Endunion
	dc.b	?
	Union
MRB	dc.b	?
	Endunion
	dc.b	?
	Union
SRB	dc.b	?
CSRB	dc.b	?
	Endunion
	dc.b	?
	Union
CRB	dc.b	?
	Endunion
	dc.b	?
	Union
RBB	dc.b	?
TBB	dc.b	?
	Endunion
	dc.b	?
	Union
IVR	dc.b	?
	Endunion
	dc.b	?
	Union
INPUT	dc.b	?
OPCR	dc.b	?
	Endunion
	dc.b	?
	Union
START_C	dc.b	?
OPR_SET	dc.b	?
	Endunion
	dc.b	?
	Union
STOP_C	dc.b	?
OPR_RES	dc.b	?
	Endunion
DUART	Endstruct
