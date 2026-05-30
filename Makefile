OUT = minecraft_c64.prg
KICK_OUT = kick3d_plain.prg
SRC = src/minecraft_kick3d.asm
BUILD_SRC = .build/minecraft_kick3d_acme.asm
KICK_BUILD_SRC = .build/kick3d_acme.asm
KICK_SRC = Kick-3D/mapping.asm Kick-3D/main.asm Kick-3D/math.asm Kick-3D/user.asm Kick-3D/display.asm Kick-3D/sprites.asm Kick-3D/raycast.asm Kick-3D/rayscan.asm Kick-3D/interrupts.asm Kick-3D/resources.asm Kick-3D/tables.asm

ASM = acme
ASMFLAGS = -f cbm
PYTHON = python3

.PHONY: all kick3d run kick-run clean

all: $(OUT)

$(BUILD_SRC) $(KICK_BUILD_SRC): $(SRC) src/minecraft_user.asm src/minecraft_resources.asm scripts/normalize_kick3d_for_acme.py $(KICK_SRC)
	$(PYTHON) scripts/normalize_kick3d_for_acme.py

$(OUT): $(BUILD_SRC)
	$(ASM) $(ASMFLAGS) -o $(OUT) $(BUILD_SRC)

$(KICK_OUT): $(KICK_BUILD_SRC)
	$(ASM) $(ASMFLAGS) -o $(KICK_OUT) $(KICK_BUILD_SRC)

kick3d: $(KICK_OUT)

run: $(OUT)
	x64sc $(OUT)

kick-run: $(KICK_OUT)
	x64sc $(KICK_OUT)

clean:
	rm -f $(OUT) $(KICK_OUT)
	rm -rf .build
