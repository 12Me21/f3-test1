AS = asl
ASFLAGS = -n -U -q +t 70 -r 3
# what the heck does +t 70 do?
P2BIN = p2bin

all: main.main.bin audiocpu3.audio.bin

main.p: font2.s shared-ram.s
audiocpu3.p: duart-68000.s otis.s shared-ram.s

%.p: %.s
	@echo "---"
	$(AS) $< $(ASFLAGS) -L -o $@

%.audio.bin: %.p
	$(P2BIN) $< $@ -r 0x0-0x07FFFF

%.main.bin: %.p
	$(P2BIN) $< $@ -r 0x0-0x1FFFFF
