player_Heading:	!word 0
player_RotSpeed:	!byte 32
player_MovSpeed:	!byte 6
player_DirVectX:	!word 0
player_DirVectY:	!word 0
player_PosX:		!word $0000
				!byte $08
player_PosY:		!word $0000
				!byte $08
player_absHeadSin	!word 0
player_absHeadCos !word 0

mc_health			!byte 8
mc_selectedSlot	!byte 0
mc_needHud		!byte 1
mc_inventory		!byte $24,$55,$89,$fe,$fd,0,0,0,0,0,0,0,0,0,0

main
			jsr setup

main_loop		jsr minecraftInput
			jsr limitPlayerPos
			jsr getDirVect
			jsr minecraftTick
			jsr rayScan
			jsr drawScreen
			jsr moveBackSpr
			jsr drawHud
			;jsr drawCursor
			jmp main_loop

userEvents
			jmp minecraftInput

setup
			lda CONTROL_REG_1
			and #%10000000
			ora #%00011011
			sta CONTROL_REG_1

			jsr initSprites

			lda #1
			sta screen_ViewMode
			lda #6
			sta player_MovSpeed
			lda #32
			sta player_RotSpeed

			lda #%00111000
			sta SPRITE_ENABLE

			lda #CYAN
			sta setInterrupt_scanColor1
			lda #GREEN
			sta setInterrupt_scanColor2
			lda #0
			sta setInterrupt_scanLine1
			lda #151
			sta setInterrupt_scanLine2

			lda #0
			sta BORDER_COLOR
			sta BCKGRND_COLOR_0

			lda #$00
			sta player_Heading
			sta player_Heading+1
			jsr getDirVect

			lda #$80
			sta player_PosX+1
			lda #8
			sta player_PosX+2
			lda #$80
			sta player_PosY+1
			lda #8
			sta player_PosY+2

			jsr setInterrupt
			jsr drawHud
			rts

minecraftInput
			jsr getKeyboard

			; W forward, S backward, A/D turn, Q/E strafe.
			lda getKeyboard_scan+1
			and #%00000010 ; check W
			beq minecraftInput_notW
			jsr playerFWD
minecraftInput_notW		lda getKeyboard_scan+1
			and #%00100000 ; check S
			beq minecraftInput_notS
			jsr invertDirVect
			jsr playerFWD
			jsr invertDirVect
minecraftInput_notS		lda getKeyboard_scan+1
			and #%00000100 ; check A
			beq minecraftInput_notA
			jsr playerROL
minecraftInput_notA		lda getKeyboard_scan+2
			and #%00000100 ; check D
			beq minecraftInput_notD
			jsr playerROR
minecraftInput_notD		lda getKeyboard_scan+7
			and #%01000000 ; check Q
			beq minecraftInput_notQ
			jsr playerSTL
minecraftInput_notQ		lda getKeyboard_scan+1
			and #%01000000 ; check E
			beq minecraftInput_notE
			jsr playerSTR

minecraftInput_notE		lda getKeyboard_scan+4
			and #%00000010 ; check up I
			beq minecraftInput_notI
			lda viewPitch
			cmp #$fa
			beq minecraftInput_notI
			dec viewPitch ; pitch down on I
minecraftInput_notI		lda getKeyboard_scan+4
			and #%00100000 ; check down K
			beq minecraftInput_notK
			lda viewPitch
			cmp #6
			beq minecraftInput_notK
			inc viewPitch

minecraftInput_notK		lda getKeyboard_scan+4
			and #%01000000 ; check down O
			beq minecraftInput_notO
			jsr eatSelected

minecraftInput_notO		lda getKeyboard_scan+7
			and #%00010000 ; check space
			beq minecraftInput_notSpace
			jsr breakTarget
minecraftInput_notSpace	lda getKeyboard_scan+0
			and #%00000010 ; check return
			beq minecraftInput_notReturn
			jsr placeTarget
minecraftInput_notReturn	jsr hotbarKeys
			rts

hotbarKeys
			lda getKeyboard_scan+7
			and #%00000001
			beq hotbarKeys_not1
			lda #0
			sta mc_selectedSlot
			inc mc_needHud
hotbarKeys_not1		lda getKeyboard_scan+7
			and #%00001000
			beq hotbarKeys_not2
			lda #1
			sta mc_selectedSlot
			inc mc_needHud
hotbarKeys_not2		lda getKeyboard_scan+1
			and #%00000001
			beq hotbarKeys_not3
			lda #2
			sta mc_selectedSlot
			inc mc_needHud
hotbarKeys_not3		lda getKeyboard_scan+1
			and #%00001000
			beq hotbarKeys_not4
			lda #3
			sta mc_selectedSlot
			inc mc_needHud
hotbarKeys_not4		lda getKeyboard_scan+2
			and #%00000001
			beq hotbarKeys_exit
			lda #4
			sta mc_selectedSlot
			inc mc_needHud
hotbarKeys_exit		rts

breakTarget
			jsr castCenterRay
			lda raySide
			beq breakTarget_exit

			ldx rayMapY
			ldy rayMapX
			jsr getCellCode
			cmp #128
			bcc breakTarget_exit

			; Store a compact item drop in inventory if possible.
			jsr addItemFromCell

			lda #$20
			ldx rayMapY
			ldy rayMapX
			jsr setCellCode

			lda #WHITE
			ldx rayMapY
			ldy rayMapX
			jsr setCellColor

			inc mc_needHud
breakTarget_exit		rts

placeTarget
			jsr castCenterRay
			lda raySide
			beq placeTarget_exit

			lda rayMapX
			sta DL
			lda rayMapY
			sta DH

			lda raySide
			cmp #1
			bne placeTarget_sideY
			lda raySignX
			bmi placeTarget_pxPlus
			dec DL
			jmp placeTarget_gotPrev
placeTarget_pxPlus		inc DL
			jmp placeTarget_gotPrev
placeTarget_sideY		lda raySignY
			bmi placeTarget_pyPlus
			dec DH
			jmp placeTarget_gotPrev
placeTarget_pyPlus		inc DH

placeTarget_gotPrev	ldx DH
			ldy DL
			jsr getCellCode
			cmp #128
			bcs placeTarget_exit

			ldx mc_selectedSlot
			lda mc_inventory,x
			beq placeTarget_exit
			jsr itemToWall
			cmp #$20
			beq placeTarget_exit

			pha
			ldx DH
			ldy DL
			pla
			pha
			jsr setCellCode
			pla
			jsr wallColor
			ldx DH
			ldy DL
			jsr setCellColor

			ldx mc_selectedSlot
			jsr decInventorySlot
			inc mc_needHud
placeTarget_exit		rts

castCenterRay
			lda player_Heading
			sta rayHeading
			lda player_Heading+1
			sta rayHeading+1
			jmp rayCast

addItemFromCell
			jsr wallToItem
			cmp #0
			beq addItemFromCell_exit
			tay
			ldx #0
addItemFromCell_loop		lda mc_inventory,x
			beq addItemFromCell_empty
			and #$f0
			sta B
			tya
			and #$f0
			cmp B
			bne addItemFromCell_next
			lda mc_inventory,x
			and #$0f
			cmp #15
			beq addItemFromCell_next
			inc mc_inventory,x
			rts
addItemFromCell_empty		tya
			sta mc_inventory,x
			rts
addItemFromCell_next		inx
			cpx #15
			bcc addItemFromCell_loop
addItemFromCell_exit		rts

decInventorySlot
			lda mc_inventory,x
			cmp #$f0
			bcs decInventorySlot_nonStack
			sec
			sbc #1
			tay
			and #$0f
			bne decInventorySlot_storeY
			lda #0
			sta mc_inventory,x
			rts
decInventorySlot_storeY		tya
			sta mc_inventory,x
			rts
decInventorySlot_nonStack	lda #0
			sta mc_inventory,x
			rts

eatSelected
			ldx mc_selectedSlot
			lda mc_inventory,x
			and #$f0
			cmp #$e0
			bne eatSelected_exit
			lda mc_health
			cmp #8
			bcs eatSelected_exit
			clc
			adc #2
			cmp #8
			bcc eatSelected_storeHealth
			lda #8
eatSelected_storeHealth
			sta mc_health
			ldx mc_selectedSlot
			jsr decInventorySlot
			inc mc_needHud
eatSelected_exit		rts

minecraftTick
			; Small random-tick placeholder matching the URCL frame hook.
			; The mutable map is the source of truth for Kick-3D rendering.
			rts

drawHud
			lda #0
			lda mc_needHud
			bne drawHud_draw
			rts
drawHud_draw		lda #0
			sta mc_needHud
			ldx #0
drawHud_hpLoop		lda #$20
			cpx mc_health
			bcs drawHud_hpEmpty
			lda #$53
drawHud_hpEmpty	sta SCREEN_RAM+24*40,x
			lda #RED
			sta COLOR_RAM+24*40,x
			inx
			cpx #8
			bcc drawHud_hpLoop

			ldx #0
drawHud_slotLoop	lda mc_inventory,x
			jsr itemGlyph
			sta SCREEN_RAM+24*40+10,x
			lda #WHITE
			cpx mc_selectedSlot
			bne drawHud_slotColor
			lda #YELLOW
drawHud_slotColor	sta COLOR_RAM+24*40+10,x
			inx
			cpx #5
			bcc drawHud_slotLoop
			rts

; !zone drawCursor
; drawCursor
; 			lda #'+'
; 			sta SCREEN_RAM+12*40+20
; 			lda #WHITE
; 			sta COLOR_RAM+12*40+20
; 			rts

itemGlyph
			cmp #0
			bne itemGlyph_notAir
			lda #$2e
			rts
itemGlyph_notAir		cmp #$fd
			bne itemGlyph_notTable
			lda #'T'
			rts
itemGlyph_notTable	cmp #$fe
			bne itemGlyph_notFurnace
			lda #'F'
			rts
itemGlyph_notFurnace	cmp #$ff
			bne itemGlyph_stackable
			lda #'C'
			rts
itemGlyph_stackable	lsr
			lsr
			lsr
			lsr
			tax
			lda itemGlyph_glyphs,x
			rts
itemGlyph_glyphs		!byte '.', 's', 'd', 'S', 'c', 'l', 'v', 'p'
			!byte 'o', 'i', 'a', 'g', 'n', 'I', '@', '*'

wallToItem
			cmp #MC_GRASS
			beq wallToItem_dirt
			cmp #MC_DIRT
			beq wallToItem_dirt
			cmp #MC_STONE
			beq wallToItem_cobble
			cmp #MC_LOG
			beq wallToItem_log
			cmp #MC_LEAVES
			beq wallToItem_leaves
			cmp #MC_PLANK
			beq wallToItem_plank
			cmp #MC_COALORE
			beq wallToItem_coal
			cmp #MC_IRONORE
			beq wallToItem_ironOre
			cmp #MC_SAND
			beq wallToItem_sand
			cmp #MC_SAPLING
			beq wallToItem_sapling
			cmp #MC_TABLE
			beq wallToItem_table
			cmp #MC_FURNACE
			beq wallToItem_furnace
			cmp #MC_CHEST
			beq wallToItem_chest
			lda #0
			rts
wallToItem_dirt		lda #$21
			rts
wallToItem_cobble		lda #$41
			rts
wallToItem_log		lda #$51
			rts
wallToItem_leaves		lda #$61
			rts
wallToItem_plank		lda #$71
			rts
wallToItem_coal		lda #$81
			rts
wallToItem_ironOre	lda #$91
			rts
wallToItem_sand		lda #$a1
			rts
wallToItem_sapling	lda #$c1
			rts
wallToItem_table		lda #$fd
			rts
wallToItem_furnace	lda #$fe
			rts
wallToItem_chest		lda #$ff
			rts

itemToWall
			cmp #$fd
			beq itemToWall_table
			cmp #$fe
			beq itemToWall_furnace
			cmp #$ff
			beq itemToWall_chest
			and #$f0
			cmp #$20
			beq itemToWall_dirt
			cmp #$30
			beq itemToWall_stone
			cmp #$40
			beq itemToWall_cobble
			cmp #$50
			beq itemToWall_log
			cmp #$60
			beq itemToWall_leaves
			cmp #$70
			beq itemToWall_plank
			cmp #$a0
			beq itemToWall_sand
			cmp #$b0
			beq itemToWall_glass
			cmp #$c0
			beq itemToWall_sapling
			lda #$20
			rts
itemToWall_dirt		lda #MC_DIRT
			rts
itemToWall_stone		lda #MC_STONE
			rts
itemToWall_cobble		lda #MC_COBBLE
			rts
itemToWall_log		lda #MC_LOG
			rts
itemToWall_leaves		lda #MC_LEAVES
			rts
itemToWall_plank		lda #MC_PLANK
			rts
itemToWall_sand		lda #MC_SAND
			rts
itemToWall_glass		lda #MC_GLASS
			rts
itemToWall_sapling	lda #MC_SAPLING
			rts
itemToWall_table		lda #MC_TABLE
			rts
itemToWall_furnace	lda #MC_FURNACE
			rts
itemToWall_chest		lda #MC_CHEST
			rts

wallColor
			cmp #MC_GRASS
			beq wallColor_green
			cmp #MC_LEAVES
			beq wallColor_green
			cmp #MC_SAPLING
			beq wallColor_green
			cmp #MC_DIRT
			beq wallColor_brown
			cmp #MC_LOG
			beq wallColor_brown
			cmp #MC_PLANK
			beq wallColor_brown
			cmp #MC_TABLE
			beq wallColor_brown
			cmp #MC_CHEST
			beq wallColor_brown
			cmp #MC_SAND
			beq wallColor_yellow
			cmp #MC_COALORE
			beq wallColor_dark
			cmp #MC_IRONORE
			beq wallColor_iron
			cmp #MC_GLASS
			beq wallColor_cyan
			lda #GRAY
			rts
wallColor_green		lda #GREEN
			rts
wallColor_brown		lda #BROWN
			rts
wallColor_yellow		lda #YELLOW
			rts
wallColor_dark		lda #DARK_GRAY
			rts
wallColor_iron		lda #LIGHT_RED
			rts
wallColor_cyan		lda #CYAN
			rts

playerFWD
			lda #0
			sta EL
			ldy player_MovSpeed
			lda player_DirVectX
			sta DL
			lda player_DirVectX+1
			sta DH
			bpl playerFWD_next1
			dec EL
playerFWD_loop1		asl DL
			rol DH
			rol EL
playerFWD_next1		dey
			bpl playerFWD_loop1
			lda DL
			clc
			adc player_PosX
			sta player_PosX
			lda DH
			adc player_PosX+1
			sta player_PosX+1
			lda EL
			adc player_PosX+2
			sta player_PosX+2

			lda #0
			sta EL
			ldy player_MovSpeed
			lda player_DirVectY
			sta DL
			lda player_DirVectY+1
			sta DH
			bpl playerFWD_next2
			dec EL
playerFWD_loop2		asl DL
			rol DH
			rol EL
playerFWD_next2		dey
			bpl playerFWD_loop2
			lda DL
			clc
			adc player_PosY
			sta player_PosY
			lda DH
			adc player_PosY+1
			sta player_PosY+1
			lda EL
			adc player_PosY+2
			sta player_PosY+2
			rts

playerROL
			ldx player_Heading+1
			lda player_Heading
			clc
			adc player_RotSpeed
			sta player_Heading
			bcc playerROL_skip
			inx
			txa
			and #%00000011
			sta player_Heading+1
playerROL_skip		rts

playerROR
			ldx player_Heading+1
			lda player_Heading
			sec
			sbc player_RotSpeed
			sta player_Heading
			bcs playerROR_skip
			dex
			txa
			and #%00000011
			sta player_Heading+1
playerROR_skip		rts

playerSTL
			lda player_Heading+1
			pha
			tay
			iny
			tya
			and #%00000011
			sta player_Heading+1
			jsr getDirVect
			jsr playerFWD
			pla
			sta player_Heading+1
			jmp getDirVect

playerSTR
			lda player_Heading+1
			pha
			tay
			dey
			tya
			and #%00000011
			sta player_Heading+1
			jsr getDirVect
			jsr playerFWD
			pla
			sta player_Heading+1
			jmp getDirVect

invertDirVect
			lda #0
			sec
			sbc player_DirVectX
			sta player_DirVectX
			lda #0
			sbc player_DirVectX+1
			sta player_DirVectX+1
			lda #0
			sec
			sbc player_DirVectY
			sta player_DirVectY
			lda #0
			sbc player_DirVectY+1
			sta player_DirVectY+1
			rts

getDirVect
			lda player_Heading
			ldx player_Heading+1
			jsr cosinus
			lda DH
			sta player_DirVectX+1
			lda DL
			sta player_DirVectX
			lda EL
			sta player_absHeadCos
			lda EH
			sta player_absHeadCos+1

			lda player_Heading
			ldx player_Heading+1
			jsr sinus
			lda DH
			sta player_DirVectY+1
			lda DL
			sta player_DirVectY
			lda EL
			sta player_absHeadSin
			lda EH
			sta player_absHeadSin+1
			rts

limitPlayerPos
			lda player_PosY+1
			cmp #80
			bcs limitPlayerPos_limitS
			ldx player_PosY+2
			dex
			ldy player_PosX+2
			jsr getCellCode
			cmp #128
			bcc limitPlayerPos_limitS
			lda #80
			sta player_PosY+1
limitPlayerPos_limitS		lda player_PosY+1
			cmp #176
			bcc limitPlayerPos_limitE
			ldx player_PosY+2
			inx
			ldy player_PosX+2
			jsr getCellCode
			cmp #128
			bcc limitPlayerPos_limitE
			lda #176
			sta player_PosY+1
limitPlayerPos_limitE		lda player_PosX+1
			cmp #176
			bcc limitPlayerPos_limitW
			ldy player_PosX+2
			iny
			ldx player_PosY+2
			jsr getCellCode
			cmp #128
			bcc limitPlayerPos_limitW
			lda #176
			sta player_PosX+1
limitPlayerPos_limitW		lda player_PosX+1
			cmp #80
			bcs limitPlayerPos_exit
			ldy player_PosX+2
			dey
			ldx player_PosY+2
			jsr getCellCode
			cmp #128
			bcc limitPlayerPos_exit
			lda #80
			sta player_PosX+1
limitPlayerPos_exit		rts

getCellCode
			lda scrAddr_lo,x
			clc
			adc #<map
			sta CL
			lda scrAddr_hi,x
			adc #>map
			sta CH
			lda (CX),y
			rts

setCellCode
			pha
			lda scrAddr_lo,x
			clc
			adc #<map
			sta CL
			lda scrAddr_hi,x
			adc #>map
			sta CH
			pla
			sta (CX),y
			rts

getCellColor
			lda scrAddr_lo,x
			clc
			adc #<colorMap
			sta CL
			lda scrAddr_hi,x
			adc #>colorMap
			sta CH
			lda (CX),y
			rts

setCellColor
			pha
			lda scrAddr_lo,x
			clc
			adc #<colorMap
			sta CL
			lda scrAddr_hi,x
			adc #>colorMap
			sta CH
			pla
			sta (CX),y
			rts

getKeyboard
			lda DDRA
			pha
			lda DDRB
			pha
			lda #$ff
			sta DDRA
			lda #$00
			sta DDRB

			lda #%01111111
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+7
			lda #%10111111
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+6
			lda #%11011111
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+5
			lda #%11101111
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+4
			lda #%11110111
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+3
			lda #%11111011
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+2
			lda #%11111101
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+1
			lda #%11111110
			sta PRA
			lda PRB
			eor #255
			sta getKeyboard_scan+0
			lda #%11111111
			sta PRA
			pla
			sta DDRB
			pla
			sta DDRA
			rts
getKeyboard_scan		!byte 0,0,0,0,0,0,0,0

memCopy
			sta EL
			stx EH
			ldy #0
			ldx #0
memCopy_loop		lda (CX),y
			sta (DX),y
			iny
			bne memCopy_skip
			inc CH
			inc DH
			inx
memCopy_skip		cpy EL
			txa
			sbc EH
			bcc memCopy_loop
			rts
