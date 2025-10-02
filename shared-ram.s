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
	
	;; 0 = main cpu, 1 = audio cpu
COMMAND_RECIEVER = dpram_addr($300)

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
	bra buffer_begin_peek
	
buffer_begin_write:
	atomic_begin_sync (A1, STREAM_WRITE_LOCK)
	bra buffer_begin_peek
	
	;; has no end_peek, because we don't touch anything
buffer_begin_peek:
	load_spin (A1, STREAM_READ), D6
	load_spin (A1, STREAM_WRITE), D7
	rts
	
buffer_end_read:
	store_spin D6, (A1, STREAM_READ)
	store_spin D7, (A1, STREAM_WRITE)
	atomic_end (A1, STREAM_READ_LOCK)
	rts
	
buffer_end_write:
	Store_spin D6, (A1, STREAM_READ)
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
	
	;; note this does not require locking, but does not
buffer_begin_peek:
	load_spin (A1, STREAM_READ), D6
	load_spin (A1, STREAM_WRITE), D7
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
	st.b COMMAND_RECIEVER 		  ; command starts on audio cpu (because it has duart) but you should begin each session by setting it explicitl
	lea STDIN_0, A1
	bsr buffer_init
	lea STDOUT_0, A1
	bsr buffer_init
	rts
	ENDIF
	
	;; todo:
	;;disable interrupts?
	

	;; misc shared stuff
	
	;; load from a nearby table of bytes (most useful for 68000)
	
load_rel_b MACRO data, register
	addi.w #(data-(.testz+2)), register
.testz:
	move.b (PC, register), register
	ENDM
	
	;; in: D0
	;; out: D0, flags
hex_char_to_ascii:	
	load_rel_b .HEX_TABLE, D0
	rts
.HEX_TABLE:
	dc.b [48]-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, [7]-1, 10, 11, 12, 13, 14, 15, [26]-1, 10, 11, 12, 13, 14, 15, [25]-1, [128]-1
	ALIGN 2
	
	;; parser state variables
parser_state = parser_variables+4*0
parser_acc = parser_variables+4*2
parser_acc_len = parser_variables+4*3
parser_acc_after = parser_variables+4*1
	
parser_eat_next MACRO state
	lea state, parser_state

	;; these all take a character in D5
ps_start_of_line:	
	cmp.b #'t', D5
	beq .command_t
	cmp.b #'r', D5
	beq .command_r
	cmp.b #'w', D5
	beq .command_w
	cmp.b #'e', D5
	beq .command_e
	cmp.b #' ', D5
	beq .valid
	parser_eat_next ps_error
	rts
.valid:
	rts
.command_t:
	moveq.w #1, parser_acc_len
	parser_eat_next ps_read_hex
	bra .valid
.command_r:
	moveq.w #1, parser_acc_len
	parser_eat_next ps_read_hex
	bra .valid
.command_w:
	parser_eat_next ps_read_hex
	bra .valid
.command_e:
	parser_eat_next ps_read_hex
	bra .valid
	
	
ps_error:	
	
