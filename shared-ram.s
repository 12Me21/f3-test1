	;; for main cpu: $C00000+offset
	;; for audio cpu: $140000+offset*2
	;; "A" buffer - input from duart, written by audio cpu, read by main cpu
SHARED_A_BUFFER = dpram_addr(0)
SHARED_A_WRITE = dpram_addr(300)
SHARED_A_READ = dpram_addr(301)
	;; "M" buffer - written by main cpu, read by audio cpu, output to duart
SHARED_M_BUFFER = dpram_addr(256)
SHARED_M_WRITE = dpram_addr(302)
SHARED_M_READ = dpram_addr(303)
	
	
	;; protocol to avoid race conditions:
	;; begin atomic operation:
	;; read the flag and set it (atomically)
	;; if the flag was already set, repeat previous step until it isn't
	;; 
	
