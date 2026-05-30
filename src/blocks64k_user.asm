!zone player
	.Heading:	!word 0
	.RotSpeed:	!byte 32
	.MovSpeed:	!byte 6
	.DirVectX:	!word 0
	.DirVectY:	!word 0
	.PosX:		!word $0000
				!byte $08
	.PosY:		!word $0000
				!byte $08
	.absHeadSin	!word 0
	.absHeadCos !word 0

!zone mc
	.health			!byte 8
	.selectedSlot	!byte 0
	.needHud		!byte 1
	.inventory		!byte $24,$55,$89,$fe,$fd,0,0,0,0,0,0,0,0,0,0

!zone main
main
			jsr setup

.loop		jsr blocks64kInput
			jsr limitPlayerPos
			jsr getDirVect
			jsr blocks64kTick
			jsr rayScan
			jsr drawScreen
			jsr moveBackSpr
			jsr drawHud
			;jsr drawCursor
			jmp .loop

userEvents
			jmp blocks64kInput

!zone setup
setup
			lda CONTROL_REG_1
			and #%10000000
			ora #%00011011
			sta CONTROL_REG_1

			jsr initSprites

			lda #1
			sta screen.ViewMode
			lda #6
			sta player.MovSpeed
			lda #32
			sta player.RotSpeed

			lda #%00111000
			sta SPRITE_ENABLE

			lda #CYAN
			sta setInterrupt.scanColor1
			lda #GREEN
			sta setInterrupt.scanColor2
			lda #0
			sta setInterrupt.scanLine1
			lda #151
			sta setInterrupt.scanLine2

			lda #0
			sta BORDER_COLOR
			sta BCKGRND_COLOR_0

			lda #$00
			sta player.Heading
			sta player.Heading+1
			jsr getDirVect

			lda #$80
			sta player.PosX+1
			lda #8
			sta player.PosX+2
			lda #$80
			sta player.PosY+1
			lda #8
			sta player.PosY+2

			jsr setInterrupt
			jsr drawHud
			rts

!zone blocks64kInput
blocks64kInput
			jsr getKeyboard

			; W forward, S backward, A/D turn, Q/E strafe.
			lda getKeyboard.scan+1
			and #%00000010 ; check W
			beq .notW
			jsr playerFWD
.notW		lda getKeyboard.scan+1
			and #%00100000 ; check S
			beq .notS
			jsr invertDirVect
			jsr playerFWD
			jsr invertDirVect
.notS		lda getKeyboard.scan+1
			and #%00000100 ; check A
			beq .notA
			jsr playerROL
.notA		lda getKeyboard.scan+2
			and #%00000100 ; check D
			beq .notD
			jsr playerROR
.notD		lda getKeyboard.scan+7
			and #%01000000 ; check Q
			beq .notQ
			jsr playerSTL
.notQ		lda getKeyboard.scan+1
			and #%01000000 ; check E
			beq .notE
			jsr playerSTR

.notE		lda getKeyboard.scan+4
			and #%00000010 ; check up I
			beq .notI
			lda viewPitch
			cmp #$fa
			beq .notI
			dec viewPitch ; pitch down on I
.notI		lda getKeyboard.scan+4
			and #%00100000 ; check down K
			beq .notK
			lda viewPitch
			cmp #6
			beq .notK
			inc viewPitch

.notK		lda getKeyboard.scan+4
			and #%01000000 ; check down O
			beq .notO
			jsr eatSelected

.notO		lda getKeyboard.scan+7
			and #%00010000 ; check space
			beq .notSpace
			jsr breakTarget
.notSpace	lda getKeyboard.scan+0
			and #%00000010 ; check return
			beq .notReturn
			jsr placeTarget
.notReturn	jsr hotbarKeys
			rts

!zone hotbarKeys
hotbarKeys
			lda getKeyboard.scan+7
			and #%00000001
			beq .not1
			lda #0
			sta mc.selectedSlot
			inc mc.needHud
.not1		lda getKeyboard.scan+7
			and #%00001000
			beq .not2
			lda #1
			sta mc.selectedSlot
			inc mc.needHud
.not2		lda getKeyboard.scan+1
			and #%00000001
			beq .not3
			lda #2
			sta mc.selectedSlot
			inc mc.needHud
.not3		lda getKeyboard.scan+1
			and #%00001000
			beq .not4
			lda #3
			sta mc.selectedSlot
			inc mc.needHud
.not4		lda getKeyboard.scan+2
			and #%00000001
			beq .exit
			lda #4
			sta mc.selectedSlot
			inc mc.needHud
.exit		rts

!zone breakTarget
breakTarget
			jsr castCenterRay
			lda raySide
			beq .exit

			ldx rayMapY
			ldy rayMapX
			jsr getCellCode
			cmp #128
			bcc .exit

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

			inc mc.needHud
.exit		rts

!zone placeTarget
placeTarget
			jsr castCenterRay
			lda raySide
			beq .exit

			lda rayMapX
			sta DL
			lda rayMapY
			sta DH

			lda raySide
			cmp #1
			bne .sideY
			lda raySignX
			bmi .pxPlus
			dec DL
			jmp .gotPrev
.pxPlus		inc DL
			jmp .gotPrev
.sideY		lda raySignY
			bmi .pyPlus
			dec DH
			jmp .gotPrev
.pyPlus		inc DH

.gotPrev	ldx DH
			ldy DL
			jsr getCellCode
			cmp #128
			bcs .exit

			ldx mc.selectedSlot
			lda mc.inventory,x
			beq .exit
			jsr itemToWall
			cmp #$20
			beq .exit

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

			ldx mc.selectedSlot
			jsr decInventorySlot
			inc mc.needHud
.exit		rts

!zone castCenterRay
castCenterRay
			lda player.Heading
			sta rayHeading
			lda player.Heading+1
			sta rayHeading+1
			jmp rayCast

!zone addItemFromCell
addItemFromCell
			jsr wallToItem
			cmp #0
			beq .exit
			tay
			ldx #0
.loop		lda mc.inventory,x
			beq .empty
			and #$f0
			sta B
			tya
			and #$f0
			cmp B
			bne .next
			lda mc.inventory,x
			and #$0f
			cmp #15
			beq .next
			inc mc.inventory,x
			rts
.empty		tya
			sta mc.inventory,x
			rts
.next		inx
			cpx #15
			bcc .loop
.exit		rts

!zone decInventorySlot
decInventorySlot
			lda mc.inventory,x
			cmp #$f0
			bcs .nonStack
			sec
			sbc #1
			tay
			and #$0f
			bne .storeY
			lda #0
			sta mc.inventory,x
			rts
.storeY		tya
			sta mc.inventory,x
			rts
.nonStack	lda #0
			sta mc.inventory,x
			rts

!zone eatSelected
eatSelected
			ldx mc.selectedSlot
			lda mc.inventory,x
			and #$f0
			cmp #$e0
			bne .exit
			lda mc.health
			cmp #8
			bcs .exit
			clc
			adc #2
			cmp #8
			bcc .storeHealth
			lda #8
.storeHealth
			sta mc.health
			ldx mc.selectedSlot
			jsr decInventorySlot
			inc mc.needHud
.exit		rts

!zone blocks64kTick
blocks64kTick
			; Small random-tick placeholder matching the URCL frame hook.
			; The mutable map is the source of truth for Kick-3D rendering.
			rts

!zone drawHud
drawHud
			lda #0
			lda mc.needHud
			bne .draw
			rts
.draw		lda #0
			sta mc.needHud
			ldx #0
.hpLoop		lda #$20
			cpx mc.health
			bcs .hpEmpty
			lda #$53
.hpEmpty	sta SCREEN_RAM+24*40,x
			lda #RED
			sta COLOR_RAM+24*40,x
			inx
			cpx #8
			bcc .hpLoop

			ldx #0
.slotLoop	lda mc.inventory,x
			jsr itemGlyph
			sta SCREEN_RAM+24*40+10,x
			lda #WHITE
			cpx mc.selectedSlot
			bne .slotColor
			lda #YELLOW
.slotColor	sta COLOR_RAM+24*40+10,x
			inx
			cpx #5
			bcc .slotLoop
			rts

; !zone drawCursor
; drawCursor
; 			lda #'+'
; 			sta SCREEN_RAM+12*40+20
; 			lda #WHITE
; 			sta COLOR_RAM+12*40+20
; 			rts

!zone itemGlyph
itemGlyph
			cmp #0
			bne .notAir
			lda #$2e
			rts
.notAir		cmp #$fd
			bne .notTable
			lda #'T'
			rts
.notTable	cmp #$fe
			bne .notFurnace
			lda #'F'
			rts
.notFurnace	cmp #$ff
			bne .stackable
			lda #'C'
			rts
.stackable	lsr
			lsr
			lsr
			lsr
			tax
			lda .glyphs,x
			rts
.glyphs		!byte '.', 's', 'd', 'S', 'c', 'l', 'v', 'p'
			!byte 'o', 'i', 'a', 'g', 'n', 'I', '@', '*'

!zone wallToItem
wallToItem
			cmp #MC_GRASS
			beq .dirt
			cmp #MC_DIRT
			beq .dirt
			cmp #MC_STONE
			beq .cobble
			cmp #MC_LOG
			beq .log
			cmp #MC_LEAVES
			beq .leaves
			cmp #MC_PLANK
			beq .plank
			cmp #MC_COALORE
			beq .coal
			cmp #MC_IRONORE
			beq .ironOre
			cmp #MC_SAND
			beq .sand
			cmp #MC_SAPLING
			beq .sapling
			cmp #MC_TABLE
			beq .table
			cmp #MC_FURNACE
			beq .furnace
			cmp #MC_CHEST
			beq .chest
			lda #0
			rts
.dirt		lda #$21
			rts
.cobble		lda #$41
			rts
.log		lda #$51
			rts
.leaves		lda #$61
			rts
.plank		lda #$71
			rts
.coal		lda #$81
			rts
.ironOre	lda #$91
			rts
.sand		lda #$a1
			rts
.sapling	lda #$c1
			rts
.table		lda #$fd
			rts
.furnace	lda #$fe
			rts
.chest		lda #$ff
			rts

!zone itemToWall
itemToWall
			cmp #$fd
			beq .table
			cmp #$fe
			beq .furnace
			cmp #$ff
			beq .chest
			and #$f0
			cmp #$20
			beq .dirt
			cmp #$30
			beq .stone
			cmp #$40
			beq .cobble
			cmp #$50
			beq .log
			cmp #$60
			beq .leaves
			cmp #$70
			beq .plank
			cmp #$a0
			beq .sand
			cmp #$b0
			beq .glass
			cmp #$c0
			beq .sapling
			lda #$20
			rts
.dirt		lda #MC_DIRT
			rts
.stone		lda #MC_STONE
			rts
.cobble		lda #MC_COBBLE
			rts
.log		lda #MC_LOG
			rts
.leaves		lda #MC_LEAVES
			rts
.plank		lda #MC_PLANK
			rts
.sand		lda #MC_SAND
			rts
.glass		lda #MC_GLASS
			rts
.sapling	lda #MC_SAPLING
			rts
.table		lda #MC_TABLE
			rts
.furnace	lda #MC_FURNACE
			rts
.chest		lda #MC_CHEST
			rts

!zone wallColor
wallColor
			cmp #MC_GRASS
			beq .green
			cmp #MC_LEAVES
			beq .green
			cmp #MC_SAPLING
			beq .green
			cmp #MC_DIRT
			beq .brown
			cmp #MC_LOG
			beq .brown
			cmp #MC_PLANK
			beq .brown
			cmp #MC_TABLE
			beq .brown
			cmp #MC_CHEST
			beq .brown
			cmp #MC_SAND
			beq .yellow
			cmp #MC_COALORE
			beq .dark
			cmp #MC_IRONORE
			beq .iron
			cmp #MC_GLASS
			beq .cyan
			lda #GRAY
			rts
.green		lda #GREEN
			rts
.brown		lda #BROWN
			rts
.yellow		lda #YELLOW
			rts
.dark		lda #DARK_GRAY
			rts
.iron		lda #LIGHT_RED
			rts
.cyan		lda #CYAN
			rts

!zone movement
playerFWD
			lda #0
			sta EL
			ldy player.MovSpeed
			lda player.DirVectX
			sta DL
			lda player.DirVectX+1
			sta DH
			bpl .next1
			dec EL
.loop1		asl DL
			rol DH
			rol EL
.next1		dey
			bpl .loop1
			lda DL
			clc
			adc player.PosX
			sta player.PosX
			lda DH
			adc player.PosX+1
			sta player.PosX+1
			lda EL
			adc player.PosX+2
			sta player.PosX+2

			lda #0
			sta EL
			ldy player.MovSpeed
			lda player.DirVectY
			sta DL
			lda player.DirVectY+1
			sta DH
			bpl .next2
			dec EL
.loop2		asl DL
			rol DH
			rol EL
.next2		dey
			bpl .loop2
			lda DL
			clc
			adc player.PosY
			sta player.PosY
			lda DH
			adc player.PosY+1
			sta player.PosY+1
			lda EL
			adc player.PosY+2
			sta player.PosY+2
			rts

playerROL
			ldx player.Heading+1
			lda player.Heading
			clc
			adc player.RotSpeed
			sta player.Heading
			bcc .skip
			inx
			txa
			and #%00000011
			sta player.Heading+1
.skip		rts

playerROR
			ldx player.Heading+1
			lda player.Heading
			sec
			sbc player.RotSpeed
			sta player.Heading
			bcs .skip
			dex
			txa
			and #%00000011
			sta player.Heading+1
.skip		rts

playerSTL
			lda player.Heading+1
			pha
			tay
			iny
			tya
			and #%00000011
			sta player.Heading+1
			jsr getDirVect
			jsr playerFWD
			pla
			sta player.Heading+1
			jmp getDirVect

playerSTR
			lda player.Heading+1
			pha
			tay
			dey
			tya
			and #%00000011
			sta player.Heading+1
			jsr getDirVect
			jsr playerFWD
			pla
			sta player.Heading+1
			jmp getDirVect

invertDirVect
			lda #0
			sec
			sbc player.DirVectX
			sta player.DirVectX
			lda #0
			sbc player.DirVectX+1
			sta player.DirVectX+1
			lda #0
			sec
			sbc player.DirVectY
			sta player.DirVectY
			lda #0
			sbc player.DirVectY+1
			sta player.DirVectY+1
			rts

getDirVect
			lda player.Heading
			ldx player.Heading+1
			jsr cosinus
			lda DH
			sta player.DirVectX+1
			lda DL
			sta player.DirVectX
			lda EL
			sta player.absHeadCos
			lda EH
			sta player.absHeadCos+1

			lda player.Heading
			ldx player.Heading+1
			jsr sinus
			lda DH
			sta player.DirVectY+1
			lda DL
			sta player.DirVectY
			lda EL
			sta player.absHeadSin
			lda EH
			sta player.absHeadSin+1
			rts

limitPlayerPos
			lda player.PosY+1
			cmp #80
			bcs .limitS
			ldx player.PosY+2
			dex
			ldy player.PosX+2
			jsr getCellCode
			cmp #128
			bcc .limitS
			lda #80
			sta player.PosY+1
.limitS		lda player.PosY+1
			cmp #176
			bcc .limitE
			ldx player.PosY+2
			inx
			ldy player.PosX+2
			jsr getCellCode
			cmp #128
			bcc .limitE
			lda #176
			sta player.PosY+1
.limitE		lda player.PosX+1
			cmp #176
			bcc .limitW
			ldy player.PosX+2
			iny
			ldx player.PosY+2
			jsr getCellCode
			cmp #128
			bcc .limitW
			lda #176
			sta player.PosX+1
.limitW		lda player.PosX+1
			cmp #80
			bcs .exit
			ldy player.PosX+2
			dey
			ldx player.PosY+2
			jsr getCellCode
			cmp #128
			bcc .exit
			lda #80
			sta player.PosX+1
.exit		rts

!zone mapAccess
getCellCode
			lda scrAddr.lo,x
			clc
			adc #<map
			sta CL
			lda scrAddr.hi,x
			adc #>map
			sta CH
			lda (CX),y
			rts

setCellCode
			pha
			lda scrAddr.lo,x
			clc
			adc #<map
			sta CL
			lda scrAddr.hi,x
			adc #>map
			sta CH
			pla
			sta (CX),y
			rts

getCellColor
			lda scrAddr.lo,x
			clc
			adc #<colorMap
			sta CL
			lda scrAddr.hi,x
			adc #>colorMap
			sta CH
			lda (CX),y
			rts

setCellColor
			pha
			lda scrAddr.lo,x
			clc
			adc #<colorMap
			sta CL
			lda scrAddr.hi,x
			adc #>colorMap
			sta CH
			pla
			sta (CX),y
			rts

!zone getKeyboard
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
			sta .scan+7
			lda #%10111111
			sta PRA
			lda PRB
			eor #255
			sta .scan+6
			lda #%11011111
			sta PRA
			lda PRB
			eor #255
			sta .scan+5
			lda #%11101111
			sta PRA
			lda PRB
			eor #255
			sta .scan+4
			lda #%11110111
			sta PRA
			lda PRB
			eor #255
			sta .scan+3
			lda #%11111011
			sta PRA
			lda PRB
			eor #255
			sta .scan+2
			lda #%11111101
			sta PRA
			lda PRB
			eor #255
			sta .scan+1
			lda #%11111110
			sta PRA
			lda PRB
			eor #255
			sta .scan+0
			lda #%11111111
			sta PRA
			pla
			sta DDRB
			pla
			sta DDRA
			rts
.scan		!byte 0,0,0,0,0,0,0,0

!zone memCopy
memCopy
			sta EL
			stx EH
			ldy #0
			ldx #0
.loop		lda (CX),y
			sta (DX),y
			iny
			bne .skip
			inc CH
			inc DH
			inx
.skip		cpy EL
			txa
			sbc EH
			bcc .loop
			rts
