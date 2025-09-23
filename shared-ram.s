	;; for main cpu: $C00000+offset
	;; for audio cpu: $140000+offset*2
	;; "A" buffer - input from duart, written by audio cpu, read by main cpu
SHARED_A_BUFFER = dpram_addr(0)
SHARED_A_READ = dpram_addr(300)
SHARED_A_WRITE = dpram_addr(301)
SHARED_A_LOCK = dpram_addr(302)
	;; "M" buffer - written by main cpu, read by audio cpu, output to duart
SHARED_M_BUFFER = dpram_addr(256)
SHARED_M_READ = dpram_addr(310)
SHARED_M_WRITE = dpram_addr(311)
SHARED_M_LOCK = dpram_addr(312)
	
	
	;; protocol to avoid race conditions:
	;; begin atomic operation:
	;; read the flag and set it (atomically)
	;; if the flag was already set, repeat previous step until it isn't
	;; now, do our stuff
	;; end atomic operation: (at this point we know we are in control)
	;; - clear the flag
	
atomic_begin_sync MACRO lock
.loop:
	nop
	tas.b lock
	bmi .loop						  ;todo: we should have a delay before checking again, so we don't slow down the other device
	ENDM

atomic_end MACRO lock
	clr.b lock
	ENDM
	
	;; these all use: D0, A0, A1

shared_begin_operation MACRO buffer, read, write, lock
	atomic_begin_sync lock
	clr.w D0
	move.b write, D0
	lea buffer, A0
	lea (A0, D0), A1				  ; write ptr
	move.b read, D0
	lea (A0, D0), A0 				  ; read ptr
	ENDM
	
shared_end_operation MACRO buffer, read, write, lock
	move.w A1, D0
	move.b D0, write
	move.w A0, D0
	move.b D0, read
	atomic_end lock
	ENDM
	
shared_a_begin:	
	shared_begin_operation SHARED_A_BUFFER, SHARED_A_READ, SHARED_A_WRITE, SHARED_A_LOCK
	rts
	
shared_a_end:	
	shared_end_operation SHARED_A_BUFFER, SHARED_A_READ, SHARED_A_WRITE, SHARED_A_LOCK
	rts
	
shared_b_begin:	
	shared_begin_operation SHARED_B_BUFFER, SHARED_B_READ, SHARED_B_WRITE, SHARED_B_LOCK
	rts
	
shared_b_end:	
	shared_end_operation SHARED_B_BUFFER, SHARED_B_READ, SHARED_B_WRITE, SHARED_B_LOCK
	rts
	
shared_check_remaining:	
	cmpa.l A1, A0
	rts
	
shared_wrap_a:
	;; ah it would be easier if the 8th bit of the pointer was always 0.
	;; maybe we should just rearrange the memory so we put a gap between the buffers (and then we can put control vars there!)
