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

The C64 version renders a first-person PETSCII view by casting rays into a
compact 16x8x16 voxel world. The center ray is also used for breaking and
placing blocks, matching the original script's "previous block/current block"
raycast behavior.

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

- `W` / `S`: move forward and backward
- `A` / `D`: turn left and right
- `J` / `L`: strafe left and right
- `I` / `K`: look up and down
- `Space`: break targeted block
- `Return`: place selected hotbar item
- `1` to `5`: select hotbar slot
- `E`: eat apple from selected slot
- `Q`: quit
