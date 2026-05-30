; Minecraft C64 port using the Kick-3D rendering path.
; The ray scanner, ray caster, wall drawing routine, PETSCII column renderer,
; math tables, sprites, and raster split are sourced from Kick-3D unchanged.

*=$0801
!basic main

!source "../Kick-3D/mapping.asm"
!source "../Kick-3D/tables.asm"
!source "../Kick-3D/math.asm"

!set MC_GRASS	= $81
!set MC_DIRT	= $82
!set MC_STONE	= $83
!set MC_COBBLE	= $84
!set MC_LOG		= $85
!set MC_LEAVES	= $86
!set MC_PLANK	= $87
!set MC_COALORE	= $88
!set MC_IRONORE	= $89
!set MC_SAND	= $8a
!set MC_GLASS	= $8b
!set MC_SAPLING	= $8c
!set MC_TABLE	= $8d
!set MC_FURNACE	= $8e
!set MC_CHEST	= $8f

!source "minecraft_user.asm"
!source "../Kick-3D/display.asm"
!source "../Kick-3D/sprites.asm"
!source "../Kick-3D/raycast.asm"
!source "../Kick-3D/rayscan.asm"
!source "../Kick-3D/interrupts.asm"
!source "minecraft_resources.asm"
