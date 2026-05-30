#  blocks C64: C64 PETSCII Port
"main mine and block building game" -inspired for Commodore 64

This is a Commodore 64 project that mirrors the gameplay structure of
urcl port by sammyuri in a PETSCII-friendly form and uses the
Kick-3D engine for rendering. The original project by:

https://github.com/sammyuri/minecraft

It keeps the same core ideas:

- nibble-like block and item IDs
- stackable and non-stackable inventory slots
- block breaking and placement
- item drops and pickup
- grass spreading, grass decay, sapling growth, and leaf decay
- player health, apples, and a compact hotbar HUD

The source entry point is `src/blocks64k_kick3d.asm`. The Makefile generates
an ACME-compatible build copy in `.build/` before assembling it. It sources Kick-3D's
ray scanner, ray caster, PETSCII column renderer, math tables, sprites, and
raster split, then maps blocks64k-style blocks/items onto Kick-3D's 40x25
solid-cell map format. The center ray is used for breaking and placing blocks.

## Build

Install ACME, then run:

```sh
make
```

The build output is:

```text
blocks64.prg
```

Optional emulator launch target:

```sh
make run
```

To build the original Kick-3D engine without the blocks64k logic:

```sh
make kick3d
```

That writes:

```text
kick3d_plain.prg
```

## Controls

- `W`: move forward
- `S`: move backward
- `A` / `D`: turn left and right
- `Z` / `C`: strafe left and right
- `I` / `K`: look up and down
- `Space`: break targeted block
- `Return`: place selected hotbar item
- `1` to `5`: select hotbar slot
- `E`: eat apple from selected slot
