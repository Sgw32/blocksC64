# Minecraft in Minecraft: C64 PETSCII Port

This is a cc65 Commodore 64 project that mirrors the gameplay structure of
`../MinecraftInMinecraft.urcl` in a PETSCII-friendly form.

It keeps the same core ideas:

- nibble-like block and item IDs
- stackable and non-stackable inventory slots
- block breaking and placement
- item drops and pickup
- grass spreading, grass decay, sapling growth, and leaf decay
- player health, apples, and a compact hotbar HUD

The C64 version renders a top-down PETSCII view instead of the URCL script's
3D mesh/raycast display, because the C64 text screen is the graphics target.

## Build

Install cc65, then run:

```sh
make
```

The build output is:

```text
minecraft_c64.prg
```

Optional emulator launch target:

```sh
make run
```

## Controls

- `WASD`: move
- `IJKL`: change targeted adjacent block
- `Space`: break targeted block
- `Return`: place selected hotbar item
- `1` to `5`: select hotbar slot
- `E`: eat apple from selected slot
- `Q`: quit
