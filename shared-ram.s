	;; for main cpu: $C00000+offset
	;; for audio cpu: $140000+offset*2
	IFDEF IS_AUDIO
SHARED_ADDR_STRIDE = 1*2
SHARED_ADDR_MASK = (~($100*SHARED_ADDR_STRIDE))
CPU_ID = 1	
	ELSEIF
SHARED_ADDR_STRIDE = 1
SHARED_ADDR_MASK = (~($100*SHARED_ADDR_STRIDE))
CPU_ID = 0
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
COMMAND_RECIEVER = dpram_addr($180)

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
	
push    macro   op
        move.ATTRIBUTE op,-(sp)
        endm

drop macro amt
	IF amt<>0
	lea.l	(amt,SP),SP
	ENDIF
	endm

	
	;; D0 - output, number of chars written
	;; D1, A0, A1 - used
	;ORG $5dde
sprintf:
	BINCLUDE "sprintf.bin"
	rts
	
	;; no registers damaged
	;; does not pop its parameters
	;; stack arguments:
	;; (SP-4).l pointer to format string
	;; (SP-8).l first argument (etc.)
printf:
.format = 8
.rest = .format+4
.buffer = -$80
	link.w A6, #.buffer
	movem.l	A1/A0/D7/D6/D1/D0, -(SP)
	pea	(.rest,A6)
	move.l	(.format,A6), -(SP)
	pea	(.buffer,A6)
	jsr sprintf
	drop 4*3
	lea (.buffer,A6), A0
	lea STDOUT_0, A1
	jsr buffer_begin_write
	move.l D0, D1
	subq.l #1, D1
	ble .exit
.loop:
	move.b (A0)+, D0
	jsr buffer_push
	dbf D1, .loop
.exit:
	jsr buffer_end_write
	movem.l	(SP)+, A1/A0/D7/D6/D1/D0
	unlk A6
	rts
	
printf4 macro count, str
	pea .string
	pea .next
	jmp printf
.string:
	dc.b str, "\0"
	align 2
.next:
	drop count*4+4
	endm

	
	;; only use this during init (to set the lock for the first time ever)!
atomic_begin_FORCE MACRO lock
	st.b lock
	ENDM
	
atomic_begin_sync MACRO lock
.loop:
	nop
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

	;; in: A1 - buffer struct
	;; out: D7w - read offset
	;; out: D6w - number of filled slots
	;; out: ZF - set if buffer is empty
buffer_begin_read:
	atomic_begin_sync (A1, STREAM_READ_LOCK)
	;; same as begin_read, but does not lock
	;; ONLY use this for checking emptyness or peeking, do not call end_read
buffer_peek_read:
	load_spin (A1, STREAM_READ), D7
	load_spin (A1, STREAM_WRITE), D6
	sub.w D7, D6
	andi.w #SHARED_ADDR_MASK, D6
	rts
	
	;; in: A1 - buffer struct
	;; out: D7w - write offset
	;; out: D6w - number of empty slots
	;; out: ZF - set if buffer is full
buffer_begin_write:
	atomic_begin_sync (A1, STREAM_WRITE_LOCK)
	;; same as begin_write, but does not lock
	;; ONLY use this for checking fullness, do not write or call end_write
buffer_peek_write:
	load_spin (A1, STREAM_WRITE), D7
	load_spin (A1, STREAM_READ), D6
	sub.w D7, D6
	subq.w #1, D6  ; subtract 1 so we never write to the final slot and break everything
	andi.w #SHARED_ADDR_MASK, D6
	rts
	
	;; in: A1 - buffer struct
	;; in: D7w - read offset
buffer_end_read:
	store_spin D7, (A1, STREAM_READ)
	atomic_end (A1, STREAM_READ_LOCK)
	rts
	
	;; in: A1 - buffer struct
	;; in: D7w - write offset
buffer_end_write:
	store_spin D7, (A1, STREAM_WRITE)
	atomic_end (A1, STREAM_WRITE_LOCK)
	rts
	
	;; in: D6w - number of REMAINING slots
	;; out: ZF - set if buffer is empty (read) or full (write)
buffer_check_remaining:	
	tst.w D6
	rts
	
	;; in: D0b - byte to write
	;; in/out: D7/D6
buffer_push:
	move.b D0, (A1, D7)
	bra buffer_increment
	
	;; A0: input. pushes nul-terminated string
_buffer_push_string_loop
	move.b (A0)+, (A1, D7)
	addq.w #SHARED_ADDR_STRIDE, D7
	andi.w #SHARED_ADDR_MASK, D7
buffer_push_string:
	tst.b (A0)
	bne _buffer_push_string_loop
	rts
	
	;; out: D0b - read byte
	;; in/out: D7/D6
buffer_pop:
	move.b (A1, D7), D0
	bra buffer_increment
	
	;; in/out: D7w - read/write offset
	;; in/out: D6w - number of remaining slots
	;; out: ZF - set if buffer is full (writing) / empty (reading)
buffer_increment:	
	addq.w #SHARED_ADDR_STRIDE, D7
	andi.w #SHARED_ADDR_MASK, D7
	subq.w #SHARED_ADDR_STRIDE, D6
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
	move.b #1, COMMAND_RECIEVER 		  ; command starts on audio cpu (because it has duart) but you should begin each session by setting it explicitl
	lea STDIN_0, A1
	bsr buffer_init
	lea STDOUT_0, A1
	bsr buffer_init
	rts
	ENDIF
	
	;; todo:
	;;disable interrupts?
	

	;; misc shared stuff
	
	;; this can't use .size notation because ATTRIBUTE can't be used in IF!
	;; anyway this is for 68000 where we don't have as many fancy addressing modes
	;; maybe there is a better way to do this but whatever
	;; before: [uuuu uuuu uuuu uuuu iiii iiii iiii iiii] i = index
	;; after:  [uuuu uuuu uuuu uuuu ???? ???? dddd dddd] d = data loaded from rom
	;; corrupts the second lowest byte, but leaves the upper word untouched
	;; note that the corrupted bits depend on the distance and direction to the data;
load_rel_b MACRO data, register
	addi.w #(data-(.testz+2)), register
.testz:
	move.b (PC, register), register
	ENDM
	
	;; in: D0
	;; out: D0, flags
hex_char_from_ascii:	
	load_rel_b .HEX_TABLE, D0
	rts
.HEX_TABLE:
	dc.b [48]-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, [7]-1, 10, 11, 12, 13, 14, 15, [26]-1, 10, 11, 12, 13, 14, 15, [25]-1, [128]-1
	ALIGN 2

	;; D0 -> D0
	;; convert a byte into 2 ascii hex digits (unpacked)
Byte_to_ascii_hex:	
	;; [0000 0000 0000 0000 0000 0000 hhhh llll]
	ror.l #4, D0
	;; [llll 0000 0000 0000 0000 0000 0000 hhhh]
	;; work on the upper half
	load_rel_b .digits, D0
	;; [llll 0000 0000 0000 ???? ???? HHHH HHHH]
	;; now:
	swap D0
	;; [???? ???? HHHH HHHH llll 0000 0000 0000]
	rol.w #4, D0
	;; [???? ???? HHHH HHHH 0000 0000 0000 llll]
	load_rel_b .digits, D0
	;; [???? ???? HHHH HHHH ???? ???? LLLL LLLL]
	rts
	;; note in this case the garbage bits will be zeros, because the data is located
	;; _after_ the code, and fewer than 256 bytes away
.digits:
	dc.b "0123456789ABCDEFG"
	
	;; parser state variables
parser_state = parser_variables+4*0
parser_acc = parser_variables+4*2 ;eventually this is gonna have to be a stack tbh
parser_acc_len = parser_variables+4*3
parser_acc_after = parser_variables+4*1
parser_data_size = parser_variables+4*4
parser_addr = parser_variables+4*5
	
parser_reset:
	;; todo
	move.l #ps_default, parser_state
	clr.l parser_acc
	clr.b parser_data_size
	rts

	;; parser function terminators
pt_eat MACRO next
	move.l #next, parser_state
	rts
	ENDM

;pt_noeat MACRO state
;	bra next
parser_finish:
	;lea (PC, ps_default-(parser_finish+2)), parser_state
	pt_eat ps_default
	rts

	;; these all take a character in D5
ps_default:	
	cmp.b #'\n', D5
	beq .command_newline
	
	cmp.b #'$', D5
	beq .dollar
	
	cmp.b #'t', D5
	beq .command_t
	
	cmp.b #'i', D5
	beq .command_i
	
	cmp.b #'s', D5
	beq .command_s
	
	cmp.b #'r', D5
	beq .command_r

	cmp.b #'a', D5
	beq .command_a

.unknown:							  ;nop
	bra parser_finish
.command_newline:					  ;nop
	bra parser_finish
.dollar:								  ;set acc
	clr.l parser_acc
	pt_eat ps_read_hex
.command_t:							  ;set target  todo: currently this must be followed by a newline otherwise it is undefined which cpu executes the next commands
	move.b parser_acc+3, COMMAND_RECIEVER ;todo: domain check on this, otherwise we're locked out lol
	bra parser_finish
.command_i:							  ;identify
	lea .msg, A2
	jsr puts
	bra parser_finish
.command_r:							  ;read. todo: implement the read sizes better, and length control
	move.l parser_addr, A0
	clr.l D0
	
	cmp.b #2, parser_data_size
	beq .word
	cmp.b #4, parser_data_size
	beq .long

	move.b (A0)+, D0
	move.l A0, parser_addr
	
	push.l D0
	printf4 1, "%02X\n"
	
	bra parser_finish
.test:
	dc.b "TEST123\0"
.word:
	move.w (A0)+, D0
	move.l A0, parser_addr
	
	push.l D0
	printf4 1, "%04X\n"
	
	bra parser_finish
.long:
	move.l (A0)+, D0
	move.l A0, parser_addr
	
	push.l D0
	printf4 1, "%08X\n"
	
	bra parser_finish

.command_s:							  ;data size
	move.b parser_acc+3, parser_data_size ;todo: bounds check!
	clr.l parser_acc
	bra parser_finish
.command_a:							  ;set addr
	move.l parser_acc, parser_addr
	clr.l parser_acc
	push.l parser_addr
	printf4 1, "@ %06X\n"
	
	bra parser_finish
.readmsg:
	dc.b "read:", 0
.msg:
	IFDEF IS_AUDIO
	dc.b "audio cpu\n\0"
	ELSEIF
	dc.b "main cpu\n\0"
	ENDIF
	
ps_read_hex:
	clr.l D0
	move.b D5, D0
	bsr hex_char_from_ascii
	bmi ps_default
	move.l parser_acc, D2
	lsl.l #4, D2
	add.b D0, D2
	move.l D2, parser_acc
	rts								  ;parser eat + cont in state

shared_do_commands:
	cmp.b #CPU_ID, COMMAND_RECIEVER
	bne .notme
	
	lea STDIN_0, A1
	jsr buffer_begin_read
	beq .done
.read:
	jsr buffer_pop
	
	clr.l D5
	move.b D0, D5
	movem.l	A1/D5/D6/D7, -(SP)
	move.l parser_state, A0
	jsr (A0)
	movem.l	(SP)+, A1/D5/D6/D7
	cmp.b #'\n', D5
	beq .done
	
	jsr buffer_check_remaining
	bne .read
.done:
	jsr buffer_end_read
	
.notme:
	rts
	
	;; takes D0
putc:
	movem.l	A1/D0/D6/D7, -(SP)
	lea STDOUT_0, A1
	jsr buffer_begin_read
	jsr buffer_push
	jsr buffer_end_read
	;move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
	movem.l	(SP)+, A1/D0/D6/D7
	rts
	
puts:									  ; takes A2 (todo: just use stack params)
	movem.l	A1/D0/D6/D7, -(SP)
	lea STDOUT_0, A1
	jsr buffer_begin_write
.loop:
	move.b (A2)+, D0
	beq .exit
	jsr buffer_push
	bra .loop
.exit:
	jsr buffer_end_write
	;move.b #DUART_CR_ENABLE_TX, (DUART_0+DUART_CRB)
	movem.l	(SP)+, A1/D0/D6/D7
	rts
	
