AS = asl
ASFLAGS = -i . -i .. -n -U -q +t 70 -r 3
P2BIN = p2bin

all: test2.bin audiocpu.bin

test2.o: font2.s

%.o: %.s
	$(AS) $< $(ASFLAGS) -o $@

audiocpu.bin: audiocpu.o
	$(P2BIN) $< $@ -r 0xC00000-0xC7FFFF

%.bin: %.o
	$(P2BIN) $< $@ -r 0x0-0x1FFFFF
