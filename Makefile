AS = asl
ASFLAGS = -n -U -q +t 70 -r 3
# what the heck does +t 70 do?
P2BIN = p2bin

all: test2.main.bin audiocpu3.audio.bin

test2.p: font2.s
audiocpu3.p: duart-68000.s otis.s

%.p: %.s
	@echo "---"
	$(AS) $< $(ASFLAGS) -L -o $@

%.audio.bin: %.p
	$(P2BIN) $< $@ -r 0xC00000-0xC7FFFF

%.main.bin: %.p
	$(P2BIN) $< $@ -r 0x0-0x1FFFFF
