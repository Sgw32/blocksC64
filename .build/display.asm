

screen_ViewMode	!byte 0				; Game view mode (0=2D, 1=3D)
screen_Column		!byte 0
screen_DrawTop	!byte 0				; Top row
screen_DrawBottom	!byte 0				; Bottom row
screen_EndRow		!byte 0
screen_ChrBuffer	!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	


; ********************************************************************************
;                                    DISPLAY EVENTS
;
; Description:	Manage display events
; ********************************************************************************

displayEvents:

			lda screen_ViewMode
			bne displayEvents_is3D
	
			; 2D display

			jsr movePlayerSpr			; Move player sprite
			jsr moveDirSpr				; Move direction spriteData
	
			lda player_Heading
			sta rayHeading
			lda player_Heading+1
			sta rayHeading+1
			jsr rayCast
	
			jmp moveRaySpr
	
			; 3D display
	
displayEvents_is3D		jsr rayScan
			jsr drawScreen
			jsr moveBackSpr
	
			rts
			


; ********************************************************************************
;                                 SET VIEW MODE
;
; Description:	Set display view mode. 0=2d, 1=3d
; ********************************************************************************

setViewMode
		
			sta screen_ViewMode
			bne setViewMode_set_3D
	
			; Set 2D mode
	
			; Set player movement speed
	
			lda #1
			sta player_MovSpeed			; Movement speed multiplier as power of 2
			lda #1
			sta player_RotSpeed			; Rotation speed in Ticks

			; Enable sprites
	
			lda #%00000111				; Enable sprites 0 to 2
			sta SPRITE_ENABLE
			
			; Set interrupt routine
	
			lda #BLACK
			sta setInterrupt_scanColor1
			sta setInterrupt_scanColor2
			lda #50
			sta setInterrupt_scanLine1
			lda #250
			sta setInterrupt_scanLine2
			
			; Show map
	
			jmp showMap		
			
			
			; Set 3D mode
	
			; Set player movement speed

setViewMode_set_3D		lda #6
			sta player_MovSpeed			; Movement speed multiplier as power of 2
			lda #32
			sta player_RotSpeed			; Rotation speed in Ticks
	
		 	; Enable sprites
	
			lda #%00111000				; Enable sprites 3 to 5
			sta SPRITE_ENABLE
			
			; Set interrupt routine

			lda #CYAN
			sta setInterrupt_scanColor1
			lda #GREEN
			sta setInterrupt_scanColor2
			lda #0
			sta setInterrupt_scanLine1
			lda #151
			sta setInterrupt_scanLine2
	
			rts
			
		

; ********************************************************************************
;                                 SHOW MAP
;
; Description:	Show map on screen
; ********************************************************************************

showMap 	lda #<map					; Copy map
			sta CL
			lda #>map
			sta CH

			lda #<SCREEN_RAM
			sta DL
			lda #>SCREEN_RAM
			sta DH

			lda #$e8					; size of memory block
			ldx #$03

			jsr memCopy 
	
			; Copy color information

showColor	lda #<colorMap
			sta CL
			lda #>colorMap
			sta CH

			lda #<COLOR_RAM
			sta DL
			lda #>COLOR_RAM
			sta DH

			lda #$e8					; size of memory block
			ldx #$03

			jmp memCopy
			


; ******************************************************************************
;                                    DRAW SCREEN
; ******************************************************************************

drawScreen: ldy #0

drawScreen_loop		sty screen_Column
  
			lda zBuffer_lo,y			; n = int(ZBuffer(column) * 8)
			sta B
			lda zBuffer_hi,y
			asl B
			rol
			asl B
			rol
  
			tax							; drawStart = tblWallTop(n)
			lda wallTop,x
			sta screen_DrawTop
			jsr applyViewPitchTop

			lda #49						; drawEnd = 49 - drawStart
			sec
			sbc screen_DrawTop
			sta screen_DrawBottom
			jsr applyViewPitchBottom

			; If rayCounter is odd then do the right column
		
			lda screen_Column
			lsr
			bcs drawScreen_right

			; Draw the left column
	
			jsr drawLeft
			jmp drawScreen_next


			; Draw the right column
	
drawScreen_right		jsr drawRight
			jsr printColumn 

			; Loop
  
drawScreen_next	 	ldy screen_Column
			iny
			cpy #80
			bcc drawScreen_loop

			rts
			


; ********************************************************************
;                             DRAW LEFT COLUMN 
; ********************************************************************

drawLeft 	; Fast buffer clear routine

			lda #0
			sta screen_ChrBuffer
			sta screen_ChrBuffer+1
			sta screen_ChrBuffer+2
			sta screen_ChrBuffer+3
			sta screen_ChrBuffer+4
			sta screen_ChrBuffer+5
			sta screen_ChrBuffer+6
			sta screen_ChrBuffer+7
			sta screen_ChrBuffer+8
			sta screen_ChrBuffer+9
			sta screen_ChrBuffer+10
			sta screen_ChrBuffer+11
			sta screen_ChrBuffer+12
			sta screen_ChrBuffer+13
			sta screen_ChrBuffer+14
			sta screen_ChrBuffer+15
			sta screen_ChrBuffer+16
			sta screen_ChrBuffer+17
			sta screen_ChrBuffer+18
			sta screen_ChrBuffer+19
			sta screen_ChrBuffer+20
			sta screen_ChrBuffer+21
			sta screen_ChrBuffer+22
			sta screen_ChrBuffer+23
			sta screen_ChrBuffer+24
  
			; 0. Clear the column
			; 1. Draw bottom break character at correct position 
			; 2. Draw top break character at correct psition
			; 3. Fill from the top to bottom break characters with the full column character

			; Prepare characters

			lda screen_DrawBottom 	; n = drawEnd / 2
			lsr						; endRow = n
			tax						; If drawEnd is odd then Carry = 1
			sta screen_EndRow		; Actual screen row [0 to 24]

			lda #10					; 10 = Full left column						    	■□
			bcs drawLeft_full_btm			; If drawEnd is odd then draw a full column char. 	■□

			; Prepare bottom left character
	
			lda #8					; 8 = partial bottom char  ■□ 
									;						   □□
drawLeft_full_btm	sta screen_ChrBuffer,x

			; Draw top break
	
			lda screen_DrawTop
			lsr						; If drawStart is odd then Carry = 1
			tax						; Store draw start row into X register
			bcc drawLeft_full_top			; If drawStart is even then draw a full column char.

			lda #2					; □□
			bne drawLeft_not_full			; ■□
	
			; Loop from start row to end row and fill with the full char 
	
drawLeft_full_top	lda #10

drawLeft_not_full	sta screen_ChrBuffer,x

			inx
			cpx screen_EndRow
			bne drawLeft_full_top

			rts 
			 

  
; ********************************************************************
;                             DRAW RIGHT COLUMN 
; ********************************************************************

drawRight	; Draw bottom right break

			lda screen_DrawBottom
			lsr
			tax
			sta screen_EndRow

			lda #5
			bcs drawRight_full_btm

			lda #4

drawRight_full_btm	ora screen_ChrBuffer,x
			sta screen_ChrBuffer,x  

			; Draw top right break

			lda screen_DrawTop
			lsr
			tax                         ; Store start row into the X register 
			bcc drawRight_full_top

			lda #1
			bne drawRight_not_full

			; Draw the rest
	
drawRight_full_top 	lda #5
  
drawRight_not_full  	ora screen_ChrBuffer,x
			sta screen_ChrBuffer,x

			inx
			cpx screen_EndRow
			bne drawRight_full_top
			rts 

			

; ********************************************************************
;                             PRINT COLUMN
; ******************************************************************** 

printColumn: 

			lda screen_Column
			lsr
			tax

			ldy screen_ChrBuffer
			lda PETscii,y
			sta SCREEN_RAM+0*40,x

			ldy screen_ChrBuffer+1
			lda PETscii,y  
			sta SCREEN_RAM+1*40,x 

			ldy screen_ChrBuffer+2
			lda PETscii,y
			sta SCREEN_RAM+2*40,x     

			ldy screen_ChrBuffer+3
			lda PETscii,y
			sta SCREEN_RAM+3*40,x

			ldy screen_ChrBuffer+4
			lda PETscii,y
			sta SCREEN_RAM+4*40,x 

			ldy screen_ChrBuffer+5
			lda PETscii,y
			sta SCREEN_RAM+5*40,x

			ldy screen_ChrBuffer+6
			lda PETscii,y
			sta SCREEN_RAM+6*40,x

			ldy screen_ChrBuffer+7
			lda PETscii,y
			sta SCREEN_RAM+7*40,x

			ldy screen_ChrBuffer+8
			lda PETscii,y
			sta SCREEN_RAM+8*40,x

			ldy screen_ChrBuffer+9
			lda PETscii,y
			sta SCREEN_RAM+9*40,x

			ldy screen_ChrBuffer+10
			lda PETscii,y
			sta SCREEN_RAM+10*40,x   

			ldy screen_ChrBuffer+11
			lda PETscii,y
			sta SCREEN_RAM+11*40,x

			ldy screen_ChrBuffer+12
			lda PETscii,y
			sta SCREEN_RAM+12*40,x

			ldy screen_ChrBuffer+13
			lda PETscii,y
			sta SCREEN_RAM+13*40,x

			ldy screen_ChrBuffer+14
			lda PETscii,y
			sta SCREEN_RAM+14*40,x

			ldy screen_ChrBuffer+15
			lda PETscii,y
			sta SCREEN_RAM+15*40,x

			ldy screen_ChrBuffer+16
			lda PETscii,y
			sta SCREEN_RAM+16*40,x

			ldy screen_ChrBuffer+17
			lda PETscii,y
			sta SCREEN_RAM+17*40,x 

			ldy screen_ChrBuffer+18
			lda PETscii,y
			sta SCREEN_RAM+18*40,x

			ldy screen_ChrBuffer+19
			lda PETscii,y
			sta SCREEN_RAM+19*40,x

			ldy screen_ChrBuffer+20
			lda PETscii,y
			sta SCREEN_RAM+20*40,x

			ldy screen_ChrBuffer+21
			lda PETscii,y
			sta SCREEN_RAM+21*40,x
	
			ldy screen_ChrBuffer+22
			lda PETscii,y
			sta SCREEN_RAM+22*40,x

			ldy screen_ChrBuffer+23
			lda PETscii,y
			sta SCREEN_RAM+23*40,x

			ldy screen_ChrBuffer+24
			lda PETscii,y
			sta SCREEN_RAM+24*40,x

			; Fast Draw Color 

			; ldx screen_column
	
			lda colorBuffer,x
			sta COLOR_RAM+0*40,x
			sta COLOR_RAM+1*40,x
			sta COLOR_RAM+2*40,x
			sta COLOR_RAM+3*40,x
			sta COLOR_RAM+4*40,x
			sta COLOR_RAM+5*40,x
			sta COLOR_RAM+6*40,x
			sta COLOR_RAM+7*40,x
			sta COLOR_RAM+8*40,x
			sta COLOR_RAM+9*40,x
			sta COLOR_RAM+10*40,x
			sta COLOR_RAM+11*40,x
			sta COLOR_RAM+12*40,x
			sta COLOR_RAM+13*40,x
			sta COLOR_RAM+14*40,x
			sta COLOR_RAM+15*40,x
			sta COLOR_RAM+16*40,x
			sta COLOR_RAM+17*40,x
			sta COLOR_RAM+18*40,x
			sta COLOR_RAM+19*40,x
			sta COLOR_RAM+20*40,x
			sta COLOR_RAM+21*40,x
			sta COLOR_RAM+22*40,x
			sta COLOR_RAM+23*40,x
			sta COLOR_RAM+24*40,x

			rts
			 
 	
			
