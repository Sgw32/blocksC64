
;--------------------------------------------------------------------------------
; User defined type (structure) "player"
;--------------------------------------------------------------------------------

player_Heading:	!word 0				; Word		Player angle in Ticks		
player_RotSpeed:	!byte 1				; Byte		Player angle rotation speed		
player_MovSpeed:	!byte 1				; Byte		Player map speed factor	
player_DirVectX:	!word 0				; Real		Player direction vector X axis component
player_DirVectY:	!word 0				; Real		Player direction vector Y axis component
player_PosX:		!word $0000			; Double	Player position x on the map
				!byte $00			;			Reminder as word and integer part as byte
player_PosY:		!word $0000			; Double	Player position y on the map 
				!byte $00			;			Reminder as word and integer part as byte
player_absHeadSin	!word 0				; Real		Absolute value of the heading sinus
player_absHeadCos !word 0				; Real		Absolute value of the heading cosinus


;--------------------------------------------------------------------------------
; User defined type (structure) "event"
; Lower two bytes of event_keyP are giving us the action:
; 00 (0) - key up
; 01 (1) - key just pressed
; 11 (3) - key down
; 10 (2) - key just released
; Note that odd values indicate that key is down, even values that key is up.
;--------------------------------------------------------------------------------

event_keyQ		!byte 0
event_keyW		!byte 0
event_keyK 		!byte 0
event_keyL 		!byte 0
event_keyO 		!byte 0
event_keyP 		!byte 0
event_keyS		!byte 0	
event_button		!byte 0					; Joystick button event buffer
	
	
;--------------------------------------------------------------------------------
; User defined type (structure) "seqencer"
;--------------------------------------------------------------------------------

;!zone evtSeqencer
;	.preset		!byte 0					; Cycle count preset for delay
;	.accum      !byte 0					; Accumulated cycle count value
;	.count		!byte 0					; Sequence rayCounter
;	.rollover	!byte 0					; Rollover value (go to 0 when value reached)
	
	

;********************************************************************************
;                                   USER EVENTS
;
; Description:	Events that control the player.
;
;********************************************************************************

userEvents		
		
			; Get event
			jsr joystickEvents			; Get and process joystick events
			jsr keyboardEvents			; Get keyboard events
			jsr procKeys				; Process keyboard events
			
			; Process events
			jsr limitPlayerPos			; Limit player position (collision detect)
			jsr doMapEvents				; Process events triggered by positoin on the map.
			
			; Events are used to control the player motion
			jmp getDirVect

			;rts



;********************************************************************************
;                             UPDATE JOYSTICK EVENTS
;
; Description:	Process joystick events, i.e. player movement.
;
;********************************************************************************	

joystickEvents 
			
			lda PRA					; To save cycle time we won't update sprites
			eor #%0111111			; unless some movement is triggered.
			bne joystickEvents_up

			rts

joystickEvents_up			lda PRA					; Test if UP
			and #%00000001
			bne joystickEvents_down
			jsr joystickUp

joystickEvents_down		lda PRA					; Test if DOWN
			and #%00000010
			bne joystickEvents_left
			jsr joystickDown

joystickEvents_left		lda PRA					; Test if LEFT
			and #%00000100         
			bne joystickEvents_right
			jsr joystickLeft  
  
joystickEvents_right		lda PRA					; Test if RIGHT
			and #%00001000
			bne joystickEvents_button
			jsr joystickRight

joystickEvents_button		lda PRA
			eor #$ff				; Invert
			and #%00010000			; Filter out a button event		
			cmp #1					; If not zero it will set Carry=1
			rol event_button		; roll carry to the buffer.
			
			;; Process button events
			;
			;lda event_button
			;and #%00000011
			;cmp #%00000001			; Just pressed
			;bne joystickEvents_exit
			;
			;; Button is just pressed
			;
			;jsr buttonJustPressed

			rts
		
	
	
;********************************************************************************
;                              JOYSTICK UP EVENT
;
; Description:	Process joystick up event.
;
;********************************************************************************

joystickUp 

			jmp playerFWD			; Player move forward
			


;********************************************************************************
;                             JOYSTICK DOWN EVENT
;
; Description:	Process joystick up event.
;
;********************************************************************************

joystickDown 

			jsr invertDirVect
			jsr playerFWD
			jmp invertDirVect



;********************************************************************************
;                              JOYSTICK LEFT EVENT
;
; Description:	Process joystick up event.
;
;********************************************************************************

joystickLeft: 

			jmp playerROL			; Player rotate left
			



;********************************************************************************
;                              JOYSTICK RIGHT EVENT
;
; Description:	Process joystick right event.
;
;********************************************************************************

joystickRight: 

			jmp playerROR		; Player rotate right
			


;********************************************************************************
;                              MOVE PLAYER FORWARD
;
; Description:	Player forward movement. It wors similar to the turtle graphics.
;				Uses unit direction vector to calculate movement.
;
; Input:		player_DirVectX		Real	Player direction vector x component
;				player_DirVectY		Real	Player direction vector y compoment
;				player_PosX			Double	Player position x on the map
;				player_PosY			Double	Player position y on the map
;				player_MovSpeed 	Byte	Player movement speed factor
;
; Outputs:		player_PosX			Double	Player position x on the map
;				player_PosY			Double	Player position y on the map	
;
; Calls:		multiply
;
; Pseudocode:		
;	player_PosX = player_PosX + player_DirVectX * player_MovSpeed
;	player_posY = player_PosY + player_DirVectY * player_MovSpeed
;********************************************************************************

playerFWD 	; X DIRECTION
	
			lda #0
			sta EL
	
			ldy player_MovSpeed

			lda player_DirVectX	
			sta DL
			lda player_DirVectX+1 
			sta DH

			bpl playerFWD_next1				; if dirVectX is negative then EL = $FF
			dec EL
			bmi playerFWD_next1
		
			; Speed multiplier
		
playerFWD_loop1		asl DL					; Multiply by player_MovSpeed (contained in Y register)	
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
			
			; Y DIRECTION

			lda #0
			sta EL
			
			ldy player_MovSpeed
	
			lda player_DirVectY
			sta DL
			lda player_DirVectY+1 
			sta DH

			bpl playerFWD_next2					; if dirVectY is negative then EL = $FF
			dec EL
			bmi playerFWD_next2
	
			; Speed multiplier
	
playerFWD_loop2		asl DL						; Multiply by player_MovSpeed (contained in Y register)
			rol DH
			rol EL
	
playerFWD_next2		dey
			bpl playerFWD_loop2	
	
			lda DL						;Remainder part is in DX, integer part is in EL
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
			


;********************************************************************************
;                             PLAYER ROTATE LEFT
;
; Description:	Rotate player to the left. 
;
; Inputs:		player_Heading
;				player_RotSpeed
;
; Outputs:		player_Heading
;
; Calls:		getDirVect
;
; Pseudocode:
;	player_Heading = pleayer.Heading + player_RotSpeed
;	If player_Heading > $0400 Then
;	    player_Heading = player_Heading - $0400
;********************************************************************************

playerROL

		ldx player_Heading+1		; Word
		lda player_Heading
		clc
		adc player_RotSpeed			; Byte
		sta player_Heading
		bcc playerROL_skip
		
		inx
		txa
		and #%00000011
		sta player_Heading+1
		
playerROL_skip	rts ;jmp getDirVect
		
             

;********************************************************************************
;                             PLAYER ROTATE RIGHT
;
; Description:	Rotate player right
;
; Inputs:		player_Heading		Word	Player angle in Ticks
;				player_RotSpeed		Byte	Player angle rotation speed
;
; Outputs:		player_Heading		Word	Player angle in Ticks
;
; Calls:		getDirVect
;
;********************************************************************************

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
			
playerROR_skip		rts ;jmp getDirVect



;********************************************************************************
;                             PLAYER STRIFE LEFT
;
; Description:	Strife player to the left.
;				To strife left first rotate the player 90 deg to the left, then
;				move forward and finally rotate player back to the original heading.
;
; Inputs:		player_Heading
;
; Calls:		getDirVect
;
; Pseudocode:
;********************************************************************************

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
			rts; jmp getDirVect
			



;********************************************************************************
;                             PLAYER STRIFE RIGHT
;
; Description:	Strife player to the right.
;				To strife left first rotate the player 90 deg to the right, then
;				move forward and finally rotate player back to the original heading.
;
; Inputs:		player_Heading
;
; Calls:		getDirVect
;
; Pseudocode:
;********************************************************************************

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
			rts ;jmp getDirVect	
			



;********************************************************************************
;                             UPDATE KEYBOARD EVENTS
;
; Description:	Process keyboard events, i.e. player movement.
;
; CIA chip has port A and port B that make a mesh. To read a row or a column, 
; chip is expecting sink, i.e. to bring down the pin to 0 V. 
; We have to tell it first if port will be for reading or read/write. 
; After that we have to bring one column and then read a row.
;
;********************************************************************************

keyboardEvents 	

			jsr getKeyboard				; Scan keyboard
	
			;Check if Q is pressed
	
			lda getKeyboard_scan+7
			and #%01000000
			cmp #1
			rol event_keyQ
	
			;Check if W is pressed
	
			lda getKeyboard_scan+1
			and #%00000010
			cmp #1
			rol event_keyW
	
			;Check if P is pressed
	
			lda getKeyboard_scan+5		; If the key is not pressed then the value will be zero.
			and #%00000010				; When compared with 1 it will set Carry to 0.
			cmp #1						; If the key is pressed then the value will be >= 1 and whe
			rol event_keyP				; compared with 1 the Carry will be set to 1.
	
			;Check if S is pressed
	
			lda getKeyboard_scan+1
			and #%000100000
			cmp #1
			rol event_keyS

			;Check if K is pressed
	
			lda getKeyboard_scan+4
			and #%000100000
			cmp #1
			rol event_keyK

			;Check if L is pressed
	
			lda getKeyboard_scan+5
			and #%000000100
			cmp #1
			rol event_keyL	
	
			;Check if O is pressed
	
			lda getKeyboard_scan+4
			and #%001000000
			cmp #1
			rol event_keyO	
	
			rts



;********************************************************************************
;                                   KEY PRESS
;
; Description:	Process key presses
;********************************************************************************

procKeys	;Check if Q is pressed

			lda event_keyQ
			lsr
			bcc procKeys_not_Q
	
			;Do if Q is pressed
	
			jsr playerSTL				; Strife left
	
			;Check if W is pressed
	
procKeys_not_Q		lda event_keyW
			lsr
			bcc procKeys_not_W
	
			;Do if W is pressed
	
			jsr playerSTR				; Strife right
	
			;Check if S is pressed

procKeys_not_W:		lda event_keyS
			and #%00000011				; Filter lower 2 bytes
			cmp #1						; Check if just pressed
			bne procKeys_exit
	
			;Do if S was just pressed
	
			lda screen_ViewMode
			eor #%00000001
			jmp setViewMode
	
procKeys_exit:		rts




;********************************************************************************
;                            SCAN KEYBOARD FOR PRESSED KEYS
;
;Description:	Scan CIA 1 register for keyboard presses.
;
;********************************************************************************

getKeyboard 

			lda DDRA				; Store DDRA and DDRB	 
			pha
			lda DDRB
			pha
	
			lda #$FF				; Set port A to be an output
			sta DDRA				; Bit X: 0=Input (read only), 1=Output (read and write)
			lda #$00				; Set port B to be an input
			sta DDRB				; Bit X: 0=Input (read only), 1=Output (read and write)
	
			; Scan keyboard
	
			lda #%01111111			; Set low (connect) port A row - scanning row 7
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+7

			lda #%10111111			; Set low (connect) port A row - scanning row 6
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+6

			lda #%11011111			; Set low (connect) port A row - scanning row 5
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+5

			lda #%11101111			; Set low (connect) port A row - scanning row 4
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+4

			lda #%11110111			; Set low (connect) port A row - scanning row 3
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+3

			lda #%11111011			; Set low (connect) port A row - scanning row 2
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+2
	
			lda #%11111101			; Set low (connect) port A row - scanning row 1
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+1

			lda #%11111110			; Set low (connect) port A row - scanning row 0
			sta PRA			
			lda PRB					; Read port B column (Bit X low = active)
			eor #255
			sta getKeyboard_scan+0
	
			lda #%11111111			; Set port A high
			sta PRA
	
			pla						; Return original values
			sta DDRB
			pla
			sta DDRA
	
			rts

;Local variables
	
getKeyboard_scan		!byte 0, 0, 0, 0, 0, 0, 0, 0
			


;********************************************************************************
;                              LIMIT PLAYER POSITION
;
; Description:	Control player movements.
;********************************************************************************

limitPlayerPos 

			;Limit movement to the N (up) 
	
			lda player_PosY+1	
			cmp #80						; Value 80 = 2.5 pixels = 0.3125
			bcs limitPlayerPos_limit_S                
  
			ldx player_PosY+2			; Most significant byte is the cell in which player is in.
			dex
			ldy player_PosX+2
			jsr getCellCode
	
			;cmp #$20 
			;beq limitPlayerPos_limit_S				; If cell is empty then don't limit.
			cmp #128					; Anything below code 128 is empty space
			bcc limitPlayerPos_limit_S

			; Correct player position Y

			lda #80						; Don't allow below 80
			sta player_PosY+1

			; Limit movement to the S (down)
  
limitPlayerPos_limit_S	lda player_PosY+1
			cmp #176
			bcc limitPlayerPos_limit_E
    
			ldx player_PosY+2  
			inx
			ldy player_PosX+2
			jsr getCellCode
	
			;cmp #$20   
			;beq limitPlayerPos_limit_E				; If cell is empty then don't limit.
			cmp #128					; Anything below code 128 is empty space
			bcc limitPlayerPos_limit_E			

			;Correct player position y
	
			lda #176					; Don't allow above 176 = 0,6875
			sta player_PosY+1
  
			;Limit movement to the E (right)
	
limitPlayerPos_limit_E	lda player_PosX+1			; If position of the player is less than 2.5 pixels
			cmp #176					; from the right edge, then check.
			bcc limitPlayerPos_limit_W 

			ldy player_PosX+2  
			iny
			ldx player_PosY+2
			jsr getCellCode
	
			;cmp #$20 
			;beq limitPlayerPos_limit_W
			cmp #128					; Anything below code 128 is empty space
			bcc limitPlayerPos_limit_W			
			

			;Correct player position x
			
			lda #176
			sta player_PosX+1

			;Limit movement to the W (left)
	
limitPlayerPos_limit_W	lda player_PosX+1
			cmp #80
			bcs limitPlayerPos_exit
    
			ldy player_PosX+2  
			dey
			ldx player_PosY+2
			jsr getCellCode

			;cmp #$20 
			;beq limitPlayerPos_exit
			cmp #128					; Anything below code 128 is empty space
			bcc limitPlayerPos_exit			

			lda #80
			sta player_PosX+1

limitPlayerPos_exit		rts

			


;********************************************************************************
;                                 GET MAP CELL CODE
;
; Description: 	Get content of the map cell.
; Input:		X			Byte		row of the map
;				Y			Byte		column of the map 
;
; Output:		A			Byte		code of the cell content  
;
; Using			CX			Virtual 	register 
;				scrAddr		Table 		with screen row addresses
;********************************************************************************

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



;********************************************************************************
;                                 GET MAP CELL CODE
;
; Description:	Set content of the map cell.
; Input:		X			Byte		row of the map
;				Y			Byte		column of the map 
;
; Output:		A			Byte		code of the cell content  
;
; Using			CX			Virtual 	register 
;				scrAddr		Table 		with screen row addresses
;********************************************************************************

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


;********************************************************************************
;                                 GET MAP CELL CODE
;
; Description: 	Get color of the cell
;
; Input:		X	Byte	row of the map
;				Y	Byte	column of the map 
;
; Output:		A	Byte	color of the cell   
;
; Using			CX			Virtual register 
;				scrAddr		Table with screen row addresses
;********************************************************************************

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
			


;********************************************************************************
;                                 GET MAP CELL CODE
;
; Description:	Set color of the cell
;
; Input:		X	Byte	row of the map
;				Y	Byte	column of the map 
;
; Output:		A	Byte	code of the cell content  
;
; Using			CX			Virtual register 
;				scrAddr		Table with screen row addresses
;********************************************************************************

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
			


;********************************************************************************
;                           GET PLAYER DIRECTION VECTOR
;
; Description: 	Get player unit direction vector.
;
; Inputs:		player_Heading		Word	Player angle in Ticks
;
; Outputs:		player_DirVectX		Real	Player direction vector x axis component
;				player_DirVectY		Real	Player direction vector y axis component
;
; Calls:		sinus, cosinus
;
;********************************************************************************

getDirVect 

			; player_DirVectX = cos(player_Heading)

			lda player_Heading			; x axis
			ldx player_Heading+1
			jsr cosinus
			lda DH
			sta player_DirVectX+1
			lda DL
			sta player_DirVectX
			
			; Also save the absolute value of cosinus (without sign)
			; player_absHeadCos = abs(cos(Heading))
			
			lda EL
			sta player_absHeadCos
			lda EH
			sta player_absHeadCos+1
			
			; player_DirVectY = sin(player_Heading)

			lda player_Heading			; y axis
			ldx player_Heading+1
			jsr sinus					; Returning inverted Y coordinate
			lda DH
			sta player_DirVectY+1
			lda DL
			sta player_DirVectY
			
			; Also save the absolute value of sinus (without sign)
			; player_absHeadSin = abs(sin(Heading))
			
			lda EL						
			sta player_absHeadSin
			lda EH
			sta player_absHeadSin+1			

			rts 
			
				
	

;********************************************************************************
;                            INVERT DIRECTION VECTOR
;
; Get player unit direction vector.
;
; Inputs:	player_DirVectX		Real	Player direction vector x axis component
;			player_DirVectY		Real	Player direction vector y axis component Ticks
;
; Outputs:	player_DirVectX		Real	Player direction vector x axis component
;			player_DirVectY		Real	Player direction vector y axis component
;
;********************************************************************************

invertDirVect 	

			lda #0						; Negating result if sign is negative.
			sec							; Two's complement.
			sbc player_DirVectX			; Instead EOR#255 and then adding 1
			sta player_DirVectX			; simply substract number from zero.
			lda #0
			sbc player_DirVectX+1
			sta player_DirVectX+1
	 
			lda #0						; Negating result if sign is negative.
			sec							; Two's complement.
			sbc player_DirVectY			; Instead EOR#255 and then adding 1
			sta player_DirVectY			; simply substract number from zero.
			lda #0
			sbc player_DirVectY+1
			sta player_DirVectY+1
	
			rts  
			
				
	

;********************************************************************************
;                                  DO MAP EVENTS
;
; Description:	Do events that are triggered on certain locations of the map.
;				Here I have prepared 8 events: A, B, C, D, E, F, G and H.
;				It can be easily expanded.
;
;********************************************************************************

doMapEvents

			ldx player_PosY+2
			ldy player_PosX+2
			jsr getCellCode				; A register = cell code
			
			cmp #$08					; Allow only 8 events (can be expanded later)
			bcs doMapEvents_exit
			
			tay
			lda mapEvent_lo,y
			sta DL
			lda mapEvent_hi,y
			sta DH
			jmp (DX)

doMapEvents_exit		rts




;--------------------------------------------------------------------------------
; Map event ET
;--------------------------------------------------------------------------------

mapEvent_ET

			rts
			
			
;--------------------------------------------------------------------------------
; 								Map event A
; When player steps on the cell, certain wall area will change color.
; After the joystick fire button is pressed, the wall will open.
;--------------------------------------------------------------------------------

mapEvent_A

			lda mapEvent_A_stepA
			bne mapEvent_A_skipA1					; If STEP 0 is done, then go to the STEP 1
			
			; STEP 0: Color the part of the wall

		 	lda #WHITE
			ldx #3						; Row 3
			ldy #31						; Collumn 31
		    jsr setCellColor 
			
			lda screen_ViewMode			; If ViewMode = 2D then update color map display
			bne mapEvent_A_skipA1
			jsr showColor
			
			inc mapEvent_A_stepA					; Go to the next step
			rts
			
mapEvent_A_skipA1		ldx #3
			ldy #31
			jmp openWall
			
mapEvent_A_stepA		!byte 0			
			


;--------------------------------------------------------------------------------
; Map event B
; Enable Mask: 00000100
;--------------------------------------------------------------------------------

mapEvent_B

			ldx #9
			ldy #35
			jmp openWall				; Open the wall if joystick button pressed.
			
			
;--------------------------------------------------------------------------------
; Map event C
;--------------------------------------------------------------------------------

mapEvent_C
			
			rts
			
			
			
;--------------------------------------------------------------------------------
; Map event D
;--------------------------------------------------------------------------------

mapEvent_D
			
			rts
			
			
			
;--------------------------------------------------------------------------------
; Map event E
;--------------------------------------------------------------------------------

mapEvent_E
			
			rts
			
			
			
;--------------------------------------------------------------------------------
; Map event F
;--------------------------------------------------------------------------------

mapEvent_F
			
			rts
			
			
			
;--------------------------------------------------------------------------------
; Map event G
;--------------------------------------------------------------------------------

mapEvent_G
			
			rts
		
		
			
;--------------------------------------------------------------------------------
; Map event H
;--------------------------------------------------------------------------------

mapEvent_H
			
			rts
			
			
; Jump table
mapEvent_H_lo			!byte <mapEvent_ET
			!byte <mapEvent_A, <mapEvent_B, <mapEvent_C, <mapEvent_D 
			!byte <mapEvent_E, <mapEvent_F, <mapEvent_G, <mapEvent_H
mapEvent_H_hi			!byte >mapEvent_ET
			!byte >mapEvent_A, >mapEvent_B, >mapEvent_C, >mapEvent_D 
			!byte >mapEvent_E, >mapEvent_F, >mapEvent_G, >mapEvent_H

			

;********************************************************************************
;                                OPEN THE WALL
;
; Description:	Opens the wall at specific location if joystick button 
;				was just pressed.
;
; Input:		Xreg	Byte	Y coordinate of the wall
;				Yreg	Byte	X coordinate of the wall
;
;********************************************************************************

openWall

			lda event_button			; Check if button was just pressed
			and #%00000011
			cmp #%00000001
			bne openWall_exit					; If not just pressed then skip
			
			; Open the wall if button is pressed
			
			lda #32						; Code to set on the map (empty space = 32)
			jsr setCellCode				; Must have Xreg and Yreg ready.
						
			; Remove the mark from the map / disable the event
			
			lda #32
			ldx player_PosY+2
			ldy player_PosX+2
			jsr setCellCode
			
			; Refresh the map
			
			lda screen_ViewMode			; If display mode is 2D then redraw the screen
			bne openWall_exit			
			jsr showMap			
			
openWall_exit		rts


	
;+----+----------------------+-------------------------------------------------------------------------------------------------------+
;|    |                      |                                Peek from $dc01 (code in paranthesis):                                 |
;|row:| $dc00:               +------------+------------+------------+------------+------------+------------+------------+------------+
;|    |                      |   BIT 7    |   BIT 6    |   BIT 5    |   BIT 4    |   BIT 3    |   BIT 2    |   BIT 1    |   BIT 0    |
;+----+----------------------+------------+------------+------------+------------+------------+------------+------------+------------+
;|0.  | #%11111110 (254/$fe) | DOWN  ($  )|   F5  ($  )|   F3  ($  )|   F1  ($  )|   F7  ($  )| RIGHT ($  )| RETURN($  )|DELETE ($  )|
;|1.  | #%11111101 (253/$fd) |LEFT-SH($  )|   e   ($05)|   s   ($13)|   z   ($1a)|   4   ($34)|   a   ($01)|   w   ($17)|   3   ($33)|
;|2.  | #%11111011 (251/$fb) |   x   ($18)|   t   ($14)|   f   ($06)|   c   ($03)|   6   ($36)|   d   ($04)|   r   ($12)|   5   ($35)|
;|3.  | #%11110111 (247/$f7) |   v   ($16)|   u   ($15)|   h   ($08)|   b   ($02)|   8   ($38)|   g   ($07)|   y   ($19)|   7   ($37)|
;|4.  | #%11101111 (239/$ef) |   n   ($0e)|   o   ($0f)|   k   ($0b)|   m   ($0d)|   0   ($30)|   j   ($0a)|   i   ($09)|   9   ($39)|
;|5.  | #%11011111 (223/$df) |   ,   ($2c)|   @   ($00)|   :   ($3a)|   .   ($2e)|   -   ($2d)|   l   ($0c)|   p   ($10)|   +   ($2b)|
;|6.  | #%10111111 (191/$bf) |   /   ($2f)|   ^   ($1e)|   =   ($3d)|RGHT-SH($  )|  HOME ($  )|   ;  ($3b)|   *   ($2a)|   £   ($1c)|
;|7.  | #%01111111 (127/$7f) | STOP  ($  )|   q   ($11)|COMMODR($  )| SPACE ($20)|   2   ($32)|CONTROL($  )|  <-   ($1f)|   1   ($31)|
;+----+----------------------+------------+------------+------------+------------+------------+------------+------------+------------+
;Source: https:;codebase64.org/doku.php?id=base:reading_the_keyboard


; SEQUENCER WITH ROLLOVER EXAMPLE
;
;locEvent_A
;
;		 	inc sequencer_A.accum
;			lda sequencer_A.accum
;			cmp sequencer_A.preset
;			bcc openWall_skipA
;			
;			lda #0
;			sta sequencer_A.accum
;			
;			inc sequencer_A.count
;			ldy sequencer_A.count
;			cpy sequencer_A.rollover
;			bcc openWall_skipB
;
;			sta sequencer_A.count		; A already contains 0	
;			
;openWall_skipB		lda glow,y
;			ldx #3						; Row 3
;			ldy #31						; Collumn 31
;		    jsr setCellColor 
;			
;			lda screen_ViewMode			; If ViewMode = 2D then update color map display
;			bne openWall_skipA
;			jmp showColor
;			
;openWall_skipA		rts
