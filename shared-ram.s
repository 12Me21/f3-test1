	;; for main cpu: $C00000+offset
	;; for audio cpu: $140000+offset*2
	IFDEF IS_AUDIO
SHARED_ADDR_STRIDE = 1*2
SHARED_ADDR_MASK = (~($100*SHARED_ADDR_STRIDE))
	ELSEIF
SHARED_ADDR_STRIDE = 1
SHARED_ADDR_MASK = (~($100*SHARED_ADDR_STRIDE))
	ENDIF
	WARNING "SHARED_ADDR_MASK = \{SHARED_ADDR_MASK}"
dpram_addr	FUNCTION x, DPRAM_0+x*SHARED_ADDR_STRIDE
	;; "A" buffer - "stdin" (audio cpu moves data from: duart recieve buffer B -> stdin)
STDIN_BUFFER = dpram_addr($000)
STDIN_READ = dpram_addr($100)
STDIN_WRITE = dpram_addr($101)
STDIN_LOCK = dpram_addr($102)
	;; "M" buffer - "stdout" (audio cpu moves data from: stdout -> duart transmit buffer B)
STDOUT_BUFFER = dpram_addr($200)
STDOUT_READ = dpram_addr($300)
STDOUT_WRITE = dpram_addr($301)
STDOUT_LOCK = dpram_addr($302)
	;; note that both cpus can read and write to either buffer.
	
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
	clr.l D7
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
	
stdin_begin:
	shared_begin_operation STDIN_BUFFER, STDIN_READ, STDIN_WRITE, STDIN_LOCK
	rts
	
stdin_end:	
	shared_end_operation STDIN_BUFFER, STDIN_READ, STDIN_WRITE, STDIN_LOCK
	rts
	
stdout_begin:	
	shared_begin_operation STDOUT_BUFFER, STDOUT_READ, STDOUT_WRITE, STDOUT_LOCK
	rts
	
stdout_end:	
	shared_end_operation STDOUT_BUFFER, STDOUT_READ, STDOUT_WRITE, STDOUT_LOCK
	rts
	
shared_check_remaining:	
	cmpa.l A1, A0
	rts
	
shared_increment_read:
	move.l A0, D7
	addq.w #SHARED_ADDR_STRIDE, D7
	andi.w #SHARED_ADDR_MASK, D7
	move.l D7, A0
	rts

shared_increment_write:
	move.l A1, D7
	addq.w #SHARED_ADDR_STRIDE, D7
	andi.w #SHARED_ADDR_MASK, D7
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
	st.b STDIN_LOCK
	clr.b STDIN_READ
	clr.b STDIN_WRITE
	sf.b STDIN_LOCK
	st.b STDOUT_LOCK
	clr.b STDOUT_READ
	clr.b STDOUT_WRITE
	sf.b STDOUT_LOCK
	rts
	ENDIF
	
	
	;; todo:
	;;disable interrupts?
	;; think about when we actually need to lock things vs just checking for lock state
	;; (e.g. it's ok to read without locking i think)
