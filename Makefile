AS = asl
ASFLAGS = -i . -i .. -n -U -q +t 70 -r 2 
P2BIN = p2bin

all: test.bin

test.o: font2.s

%.o: %.s
	$(AS) $< $(ASFLAGS) -o $@

%.bin: %.o
	$(P2BIN) $< $@ -r 0x0-0x1FFFFF
