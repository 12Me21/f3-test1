	;; for main cpu: $C00000+offset
	;; for audio cpu: $140000+offset*2
	;; "A" buffer - input from duart, written by audio cpu, read by main cpu
SHARED_A_BUFFER = dpram_addr($000)
SHARED_A_READ = dpram_addr($100)
SHARED_A_WRITE = dpram_addr($101)
SHARED_A_LOCK = dpram_addr($102)
	;; "M" buffer - written by main cpu, read by audio cpu, output to duart
SHARED_M_BUFFER = dpram_addr($200)
SHARED_M_READ = dpram_addr($300)
SHARED_M_WRITE = dpram_addr($301)
SHARED_M_LOCK = dpram_addr($302)
	IFDEF IS_AUDIO
SHARED_WRAP_BIT = 8+1
SHARED_STRIDE = 1*2
	ELSEIF
SHARED_WRAP_BIT = 8
SHARED_STRIDE = 1
	ENDIF	
	
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
	
	;; these all use: D7, A0, A1

shared_begin_operation MACRO buffer, read, write, lock
	atomic_begin_sync lock
	clr.w D7
	lea buffer, A0
	move.b write, D7
	IFDEF IS_AUDIO
	asl.w D7
	ENDIF
	lea (A0, D7), A1				  ; write ptr
	move.b read, D7
	IFDEF IS_AUDIO
	asl.w D7
	ENDIF
	lea (A0, D7), A0 				  ; read ptr
	ENDM
	
shared_end_operation MACRO buffer, read, write, lock
	move.w A1, D7
	IFDEF IS_AUDIO
	asr.w D7
	ENDIF
	move.b D7, write
	move.w A0, D7
	IFDEF IS_AUDIO
	asr.w D7
	ENDIF
	move.b D7, read
	atomic_end lock
	ENDM
	
shared_a_begin:
	shared_begin_operation SHARED_A_BUFFER, SHARED_A_READ, SHARED_A_WRITE, SHARED_A_LOCK
	rts
	
shared_a_end:	
	shared_end_operation SHARED_A_BUFFER, SHARED_A_READ, SHARED_A_WRITE, SHARED_A_LOCK
	rts
	
shared_m_begin:	
	shared_begin_operation SHARED_M_BUFFER, SHARED_M_READ, SHARED_M_WRITE, SHARED_M_LOCK
	rts
	
shared_m_end:	
	shared_end_operation SHARED_M_BUFFER, SHARED_M_READ, SHARED_M_WRITE, SHARED_M_LOCK
	rts
	
shared_check_remaining:	
	cmpa.l A1, A0
	rts
	
shared_increment_read:
	move.l A0, D7
	addq.w #SHARED_STRIDE, D7
	bclr.l #SHARED_WRAP_BIT, D7
	move.l D7, A0
	rts

shared_increment_write:
	move.l A1, D7
	addq.w #SHARED_STRIDE, D7
	bclr.l #SHARED_WRAP_BIT, D7
	move.l D7, A1
	rts
	
shared_push:
	move.b D0, (A1)
	jsr shared_increment_write
	rts
	
shared_pop:
	move.b (A0), D0
	jsr shared_increment_read
	rts
	
	IFDEF AUDIO
	ELSE
	;; only one cpu should do this!
shared_init:	
	st.b SHARED_A_LOCK
	clr.b SHARED_A_READ
	clr.b SHARED_A_WRITE
	sf.b SHARED_A_LOCK
	st.b SHARED_M_LOCK
	clr.b SHARED_M_READ
	clr.b SHARED_M_WRITE
	sf.b SHARED_M_LOCK
	rts
	ENDIF
	
	
	;; todo:
	;;disable interrupts?
	;; think about when we actually need to lock things vs just checking for lock state
	;; (e.g. it's ok to read without locking i think)
