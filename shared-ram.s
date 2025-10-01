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
STDIN_READ_LOCK = dpram_addr($100)
STDIN_READ = dpram_addr($101)
STDIN_WRITE_LOCK = dpram_addr($102)
STDIN_WRITE = dpram_addr($103)
	;; "M" buffer - "stdout" (audio cpu moves data from: stdout -> duart transmit buffer B)
STDOUT_BUFFER = dpram_addr($200)
STDOUT_READ_LOCK = dpram_addr($200)
STDOUT_READ = dpram_addr($201)
STDOUT_WRITE_LOCK = dpram_addr($202)
STDOUT_WRITE = dpram_addr($203)
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
	
atomic_begin_sync MACRO lock
.loop:
	nop2
	tas.b lock
	bmi .loop ;todo: we should have a delay before checking again, so we don't slow down the other device
	ENDM

atomic_end MACRO lock
	clr.b lock
	ENDM
	
;; these all use: D7, A1

shared_begin_operation MACRO buffer, lock
	atomic_begin_sync lock
	clr.l D7
	lea buffer, A1
	move.b lock+1, D7
	IFDEF IS_AUDIO
	asl.w #1, D7
	ENDIF
	lea (A1, D7), A1
	ENDM
	
shared_end_operation MACRO buffer, lock
	move.w A1, D7
	IFDEF IS_AUDIO
	asr.w #1, D7
	ENDIF
	move.b D7, lock+1
	atomic_end lock
	ENDM
	
	;; A1: ptr to the lock !
shared_begin:
.loop:
	nop2
	tas.b (A1)
	bmi .loop
	move.w A1, D7 					  ; D7 = [.... ..n0 0000 00rL]
	
	;; what we want to do:
	;; 1: read the read/write ptr
	;; 2: change A1 to point to the buffer
	;; 3: add the read/write ptr to A1
	
	;; orr.. what if we just  made A1 point to the buffer the whole time and always offset it by D7
	;; at first D7 can be the location of the lock, and then later it can be the pointer value!
	;; also... how are we going to end the operation later?
	;; do we have to set D7 ~~and A1~~ again then?
	
	move.b (A1, D7, 1), D7			  ;get the read/write pointer
	IFDEF IS_AUDIO
	asl.w #1, D7
	ENDIF
	
	rts
	
stdin_begin:
	shared_begin_operation STDIN_BUFFER, STDIN_READ_LOCK
	rts
	
stdin_end:	
	shared_end_operation STDIN_BUFFER, STDIN_READ_LOCK
	rts
	
stdout_begin:	
	shared_begin_operation STDOUT_BUFFER, STDOUT_READ_LOCK
	rts
	
stdout_end:	
	shared_end_operation STDOUT_BUFFER, STDOUT_READ_LOCK
	rts
	
shared_check_remaining:	
	cmpa.l A1, A0
	rts
	
	;; new protocol:
	;; <buffer>_begin_read (locks for read, sets A0)
	;; <buffer>_begin_write (locks for write, sets A0)
	;; <buffer>_end_read (writes A0, unlocks for read)
	;; <buffer>_end_write (writes A0, unlocks for write)
	;; shared_pop / shared_push
	;; shared_increment (the usual)
shared_push2:	
;	move.b D0, (A1, D7*2)
;	addq.b 1, D7
	rts
	

	;; tbh it's probably not worth using address registers for this
	;; or maybe use (A1, D7) or something. ah but then that wastes e.g. D6,D7,A1 instead of D7,A1,A0
	
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
	st.b STDIN_READ_LOCK
	clr.b STDIN_READ
	clr.b STDIN_WRITE
	sf.b STDIN_READ_LOCK
	st.b STDOUT_READ_LOCK
	clr.b STDOUT_READ
	clr.b STDOUT_WRITE
	sf.b STDOUT_READ_LOCK
	rts
	ENDIF
	
	
	;; todo:
	;;disable interrupts?
	;; think about when we actually need to lock things vs just checking for lock state
	;; (e.g. it's ok to read without locking i think)
