

playerSprite_OffsetX	!byte 2				; Byte
playerSprite_OffsetY	!byte 2				; Byte



dirSprite_OffsetX	!byte 1				; Byte
dirSprite_OffsetY	!byte 1				; Byte



raySprite_OffsetX	!byte 2				; Byte
raySprite_OffsetY	!byte 2				; Byte
	
	

backSprite_Heading	!word 0				; Back sprite 0
				!word 0				; Back sprite 1
				!word 0				; Back sprite 2
				!word 0				; Back sprite 3
				!word 12			; Back sprite 4
				!word 24			; Back sprite 5
				!word 0				; Back sprite 6
				!word 0				; Back sprite 7
				
backSprite_Azimuth	!byte 70


; ********************************************************************************
;                                   INITIALIZE SPRITES
; ********************************************************************************

initSprites

			lda #128				; Set sprite start memory block
			sta B
			ldy #0
	
initSprites_loop		sta SPRITE_PTR,Y
			inc B
			lda B
			iny
			cpy #6
			bcc initSprites_loop
	
			; Set sprite expand mode
	
			lda #0
			sta SPRITE_EXPAND_X
			sta SPRITE_EXPAND_Y
	
			; Set sprite color mode
	
			lda #%00111000			; Sprites 0 to 2 are hires
			sta SPRITE_MCM			; Sprites 3 to 5 are multicolor
	
			; Set sprite color
	
			lda #YELLOW
			sta SPRITE_0_COLOR
			sta SPRITE_1_COLOR
			sta SPRITE_2_COLOR
			sta SPRITE_3_COLOR
			sta SPRITE_4_COLOR
			sta SPRITE_5_COLOR
			
			; Set multicolor sprites
	
			lda #WHITE
			sta SPRITE_MCOLOR_0
			lda #LIGHT_GRAY
			sta SPRITE_MCOLOR_1
	
			; Set sprite priority
	
			lda #%00111000				; Sprites 0 to 2 are in front of the text
			sta SPRITE_PRIORITY			; Sprites 3 to 5 are behind the text
			
			; Set height for the background sprite
			
			lda backSprite_Azimuth
			sta SPRITE_3_Y_POS
			sta SPRITE_4_Y_POS
			sta SPRITE_5_Y_POS
	
			rts
			
			


; ********************************************************************************
;                             GET SPRITE X COORDINATE
;
; Description:	Calculate sprite screen X position in pixels.
; 
; Inputs:    	position	Real	Stored in X and A registers!
;			Position on the screen in FIXED POINT format.            
;		/X register 	contains the high byte of the position,
;			i.e. integer part that represents the screen cell.
;		/A register 	contains the low byte of the posion, 
;			i.e. the remainder part that represents
;			the position inside the cell.
;
;	offset	Byte	Offset from the left side stored in Y register
;		/Y register
;
; Outputs:	result	Word	Stored in X and A registers! (also in DX)
;			The sprite x position in PIXELS
;		/A register 	will contain the lo-byte
;			of the x position
;		/X register	will containt he hi-byte
;			of the x position
;
; Pseudocode:
;	result = position * 8 + SPRITE_MGN_LEFT - offset
; ********************************************************************************

getSpriteX 	
	
			sty B                       ; Store offset into B register

			stx DL                      ; Store position hi-byte into DL
			ldx #0                      ; Store 0 into DH
			stx DH

			asl                         ; Catch Carry if negative
			rol DL                      ; A register contains lo-byte of the position
			rol DH
			asl 
			rol DL
			rol DH  
			asl 
			rol DL
			rol DH

			lda DL
			clc
			adc #SPRITE_MGN_LEFT
			sta DL
			bcc getSpriteX_skip1
			inc DH

getSpriteX_skip1		lda DL
			sec
			sbc B
			sta DL
			bcs getSpriteX_skip2
			dec DH

getSpriteX_skip2		ldx DH
			rts 
			 
			


; ********************************************************************************
;                              GET SPRITE Y COORDINATE
;
; Calculate sprite screen y position in pixels.
; 
; Input:	position	Real	Stored in X and A registers!
;								Position on the screen in FIXED POINT format.            
;				/X register 	contains the hi-byte of the position,
;								i.e. integer part that represents
;								the screen cell.
;				/A register		contains the lo-byte of the posion, 
;								i.e. the fractional part that represents
;								the position inside the cell.
;
;			offset		Byte	Stored in Y register!
;				/Y register	contains the ofsset in pixels
;
; Outputs:	result		Word	Stored in X and A registers! (also in DX)
;								The sprite y position in PIXELS
;				/A register		will contain the lo-byte
;								of the y position
;				/X register		will containt he hi-byte
;								of the y position
;
; Pseudocode:
;				result = position * 8 + SPRITE_MGN_TOP - offset
; ********************************************************************************

getSpriteY 	

			sty B
			stx DH

			asl                         ; Catch Carry if negative
			rol DH                      ; A register contains lo-byte of the position
			asl 
			rol DH
			asl 
			rol DH

			lda DH
			clc
			adc #SPRITE_MGN_TOP
			sta DH

			lda DH
			sec
			sbc B
			sta DH

			rts 
			
			  


; ********************************************************************************
;                          SET SPRITE MOST SIGNIFICANT BIT
;
; Description:	Set sprite most sifnificant bit into the SPRITE_X_MSB
;
; Inputs:	X register	Byte	High byte of the screen position
;	
;	Y register	Byte	Sprite number
;
; ******************************************************************************** 

setSpriteXMSB: 	
	
			cpx #1
			bne setSpriteXMSB_noHiBit

			lda bitMask,y
			ora SPRITE_X_MSB
			sta SPRITE_X_MSB
	
			rts
	
			; Hi bit not active

setSpriteXMSB_noHiBit	lda bitMask,y
			eor #%11111111
			and SPRITE_X_MSB
			sta SPRITE_X_MSB 
	
			rts
			
			


; ********************************************************************************
;                                  MOVE PLAYER SPRITE
;
; Description:	Update player sprite position. 
; 	Player sprite ID = 0
; ********************************************************************************      

movePlayerSpr	

			lda player_PosX+1
			ldx player_PosX+2
			ldy playerSprite_OffsetX
			jsr getSpriteX	
	
			; A register contains low byte of the x position 
	
			sta SPRITE_0_X_POS

			; X register contains high byte of the x position 
	
			ldy #0						; Sprite index = 0
			jsr setSpriteXMSB

			; Set Y position
	
			lda player_PosY+1
			ldx player_PosY+2
			ldy playerSprite_OffsetY
			jsr getSpriteY  
	
			; A register contains low byte of the y position 
	
			sta SPRITE_0_Y_POS

			rts
			
			



; ********************************************************************************
;                             MOVE DIRECTION SPRITE
;
; Description:	Update direcition sprite position. 
;	Direction sprite ID = 2.
; ******************************************************************************** 

moveDirSpr:	
	
			lda player_DirVectX+1
  			sta B
  			lda player_DirVectX
  
			clc
			adc player_PosX+1
			tay
			lda B
			adc player_PosX+2
	
			tax							; X = hi-byte position
			tya							; A = lo-byte position
			ldy dirSprite_OffsetX		; Y = offset
	
			; A register constains the low byte of the x position

  			jsr getSpriteX		
			sta SPRITE_2_X_POS
	
			; X register contains high byte of the x position 
	
			ldy #2						; Sprite index = 2
			jsr setSpriteXMSB
  
			lda player_DirVectY+1
			sta B
			lda player_DirVectY

			clc
			adc player_PosY+1
			tay
			lda B
			adc player_PosY+2
	
			tax							; X = hi-byte position
			tya							; A = lo-byte position
			ldy dirSprite_OffsetY		; Y = offset
			jsr getSpriteY  
			sta SPRITE_2_Y_POS

			rts
			
			


; ********************************************************************************
;                                MOVE RAY SPRITE
; 
; Inputs:	raySignX
;	rayDeltaX 
;
; ********************************************************************************

moveRaySpr

			lda raySignX		
			bpl moveRaySpr_isPX

			lda player_PosX+1			; If raySignX < 0 then
			sec							;     x = player_PosX - rayDeltaX   (B=lo-byte, A=hi-byte)
			sbc rayDeltaX
			sta B
			lda player_PosX+2
			sbc rayDeltaX+1
			jmp moveRaySpr_skip1

moveRaySpr_isPX		lda player_PosX+1			; If raySignX >= 0 then	
			clc							;     x = player_PosX + rayDeltaX   (B=lo-byte, A=hi-byte)
			adc rayDeltaX
			sta B
			lda player_PosX+2
			adc rayDeltaX+1
  
moveRaySpr_skip1		tax
			lda B
			ldy raySprite_OffsetX
			jsr getSpriteX
	
			sta SPRITE_1_X_POS			; Set the lo-byte position

			; X register contains high byte of the x position 
	
			ldy #1						; Sprite index = 1
			jsr setSpriteXMSB			; Set the MSB byte of the X position

			; Y axis

			lda raySignY
			bpl moveRaySpr_isPY

			lda player_PosY+1			; If raySignY < 0  then
			sec							; Y = plPosY - rayDeltaY   (B=lo-byte, A=hi-byte)
			sbc rayDeltaY
			sta B
			lda player_PosY+2
			sbc rayDeltaY+1
			jmp moveRaySpr_skip2

moveRaySpr_isPY		lda player_PosY+1			; If raySignY >= 0 then
			clc							; B = plPosY + rayDeltaY   (B=lo-byte, A=hi-byte)
			adc rayDeltaY
			sta B
			lda player_PosY+2
			adc rayDeltaY+1
  
moveRaySpr_skip2		tax
			lda B
			ldy raySprite_OffsetY
			jsr getSpriteY
	
			sta SPRITE_1_Y_POS  

			rts 
			
			
			
; ********************************************************************************
;                                MOVE BACKGROUND SPRITE
; 
;
; ********************************************************************************

moveBackSpr: 
			
			ldy #3
			
moveBackSpr_loop		tya
			asl
			tax
			
			; DX = player_Heading + backSprite[x]moveBackSpr_Heading
			
			lda backSprite_Heading,x
			clc
			adc player_Heading
			sta DL
			lda backSprite_Heading+1,x
			adc player_Heading+1
			
			; DX = DX * 2
			
			asl DL
			rol
			
			; Limit angle between 0 and 2047 ($07ff)
			
			and #%00000111
			sta DH
			
			; Check if DX < 320
			
			lda DL
			cmp #$50
			lda DH
			sbc #$01
			bcc moveBackSpr_isLess
			
			; If greater than 320 then disable the sprite
			
			lda bitMask,y
			eor #$ff
			and SPRITE_ENABLE
			sta SPRITE_ENABLE
			
			jmp moveBackSpr_next
			
			; DX < 320 and DX >=0

moveBackSpr_isLess		lda bitMask,y
			ora SPRITE_ENABLE
			sta SPRITE_ENABLE
			
			lda DL
			sta SPRITE_0_X_POS,x
			
			lda DH
			beq moveBackSpr_noHiBit
			
			; Hi bit is active
			
			lda bitMask,y
			ora SPRITE_X_MSB
			sta SPRITE_X_MSB
			
			jmp moveBackSpr_next
			
			; Hi bit is not active
			
moveBackSpr_noHiBit	lda bitMask,y
			eor #$ff
			and SPRITE_X_MSB
			sta SPRITE_X_MSB
			
moveBackSpr_next		iny
			cpy #6
			bcc moveBackSpr_loop
			
			rts
			
		
