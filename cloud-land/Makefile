.PHONY: all clean

# cc65 toolchain location (override with: make CA65=/path/to/ca65 LD65=/path/to/ld65)
CA65 ?= /tmp/cc65-build/bin/ca65
LD65 ?= /tmp/cc65-build/bin/ld65

ASM_FILES := $(wildcard src/*.asm) $(wildcard src/data/*.asm)

all: cloud-land.nes

cloud-land.nes: $(ASM_FILES) nes.cfg
	$(CA65) -I src -o main.o src/main.asm
	$(LD65) -C nes.cfg -o cloud-land.nes main.o
	@rm -f main.o
	@echo "Build complete: cloud-land.nes"

test-win: $(ASM_FILES) nes.cfg
	$(CA65) -I src -D TEST_WIN -o main.o src/main.asm
	$(LD65) -C nes.cfg -o cloud-land-test-win.nes main.o
	@rm -f main.o
	@echo "Test build: cloud-land-test-win.nes"

clean:
	rm -f *.o *.nes
