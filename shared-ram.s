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

STREAM STRUCT
BUFFER dc.b [$100*SHARED_ADDR_STRIDE]?
READ_LOCK dc.b	[SHARED_ADDR_STRIDE]?
READ dc.b [SHARED_ADDR_STRIDE]?
WRITE_LOCK dc.b [SHARED_ADDR_STRIDE]?
WRITE	dc.b [SHARED_ADDR_STRIDE]?
STREAM ENDSTRUCT	

	;; "A" buffer - "stdin" (audio cpu moves data from: duart recieve buffer B -> stdin)
STDIN_0 = dpram_addr($000)
	;; "M" buffer - "stdout" (audio cpu moves data from: stdout -> duart transmit buffer B)
STDOUT_0 = dpram_addr($200)
	;; note that both cpus can read and write to either buffer.
	
	;; important! the buffers must have an address pattern like:
	;;  <etc>n0aaaaaaaa] (main cpu)
	;; <etc>n0aaaaaaaa0] (audio cpu)
	;; i.e. put a gap between them of the same size as the buffer
	
	;; protocol to avoid race conditions:
	;; begin atomic operation:
	;; read the flag and set it (atomically)
	;; if the flag was already set, repeat previous step until it isn't
	;; now, do our stuff
	;; end atomic operation: (at this point we know we are in control)
	;; - clear the flag

nop2 MACRO
	IFDEF IS_AUDIO
	nop
	ELSEIF
	trapf								  ;on 68020, nop has other effects
	ENDIF
	ENDM
	
	;; only use this during init (to set the lock for the first time ever)!
atomic_begin_FORCE MACRO lock
	st.b lock
	ENDM
	
atomic_begin_sync MACRO lock
.loop:
	nop2
	tas.b lock
	bmi .loop ;todo: we should have a delay before checking again, so we don't slow down the other device
	ENDM

atomic_end MACRO lock
	sf.b lock
	ENDM
	
load_spin MACRO location, register
	clr.w register
	move.b location, register
	IFDEF IS_AUDIO
	asl.w #1, register
	ENDIF
	ENDM
	
store_spin MACRO register, location
	IFDEF IS_AUDIO
	asr.w #1, register
	ENDIF
	move.b register, location
	ENDM
	
	;; register usage:
	;; D6: read offset
	;; D7: write offset
	;; A1: pointer to buffer struct
buffer_begin_read:
	atomic_begin_sync (A1, STREAM_READ_LOCK)
	load_spin (A1, STREAM_READ), D6
	load_spin (A1, STREAM_WRITE), D7
	rts
	
buffer_begin_write:
	atomic_begin_sync (A1, STREAM_WRITE_LOCK)
	load_spin (A1, STREAM_READ), D6
	load_spin (A1, STREAM_WRITE), D7
	rts
	
buffer_end_read:
	store_spin D6, (A1, STREAM_READ)
	store_spin D7, (A1, STREAM_WRITE)
	atomic_end (A1, STREAM_READ_LOCK)
	rts
	
buffer_end_write:
	store_spin D6, (A1, STREAM_READ)
	store_spin D7, (A1, STREAM_WRITE)
	atomic_end (A1, STREAM_WRITE_LOCK)
	rts
	
buffer_check_remaining:	
	cmp.w D7, D6
	rts
	
	;; D0: input
buffer_push:
	move.b D0, (A1, D7)
buffer_increment_write:
	addq.w #SHARED_ADDR_STRIDE, D7
	andi.w #SHARED_ADDR_MASK, D7
	rts
	
	;; D0: output
buffer_pop:
	move.b (A1, D6), D0
buffer_increment_read:
	addq.w #SHARED_ADDR_STRIDE, D6
	andi.w #SHARED_ADDR_MASK, D6
	rts
	
	IFDEF AUDIO
	ELSE
	;; only one cpu should do this!
buffer_init:	
	atomic_begin_FORCE (A1, STREAM_READ_LOCK)
	clr.b (A1, STREAM_READ)
	clr.b (A1, STREAM_WRITE)
	atomic_end (A1, STREAM_READ_LOCK)
	rts
	
setup_shared:
	lea STDIN_0, A1
	bsr buffer_init
	lea STDOUT_0, A1
	bsr buffer_init
	rts
	ENDIF
	
	;; todo:
	;;disable interrupts?
