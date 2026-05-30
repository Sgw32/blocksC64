

; ******************************************************************************
;                                    RAY SCAN 
;
; FOV = 56°
; FOV = 160 Ticks
; Number of scans = 40
; Scan step = FOV / Number_of_scans = 160 / 40 = 4 ticks
;
; 
; ******************************************************************************

rayScan 

; Variables
!set FOV 		= 160			; FOV = 160 Ticks (56°)
!set Step 		= 4				; 2=80 scans, 4=40 scans
!set HalfFOV	= FOV/2
!set Scans		= FOV/Step		; number of scans

			lda #0
			sta rayCounter

			lda player_Heading			; rayHeading = player_Heading - scanHalfFov
			clc
			adc #HalfFOV				; scanHalfFov = FOV/2 = 160/2 = 80
			sta rayHeading
			lda player_Heading+1
			adc #0	
	
rayScan_loop		and #%00000011				; limit angle between $0000 and $03ff
			sta rayHeading+1

 			jsr rayCast					; castRay returns rayDistance
			jsr rayBuffering			; store ray in the Z-Buffer
	
			; Exit if all rays are casted 
                
			inc rayCounter
			lda rayCounter
			cmp #Scans
			bcs rayScan_exit
	
			; We are scanning from left to right - angle decreases

			lda rayHeading				; rayHeading = rayHeading - scanStep
			sec
			sbc #Step					; step = FOV / number_of_scans
			sta rayHeading		
			lda rayHeading+1
			sbc #0
			jmp rayScan_loop
			
rayScan_exit		rts  

			

; ******************************************************************************
;                                   BUFFER RAY DISTANCES 
; 
; Input:	rayHeading
;	player_Heading
;	rayDistance	
;
;
; Output:   zBufferHi     Array(80) of Byte 
;           zBufferLo     Array(80) of Byte  
;           colorBuffer   Array(80) of Byte
;
; Calculate the projected distance:
; prjDistance = cos(rayAngle - plAngle) * rayDistance
;
; Calls:	
;
; ******************************************************************************

	; Calculate projected distance

rayBuffering

			lda rayHeading				; theta = rayAngle - plAngle
			sec 
			sbc player_Heading
			tay
			lda rayHeading+1
			sbc player_Heading+1
			and #%00000011
	
			tax  						; Calculate cos(theta)
			tya
			jsr cosinus					; Result is in DX

			lda rayDistance				; projectedDistance = cos(theta) * rayDistance
			sta CL
			lda rayDistance+1
			sta CH
			jsr multiply
	
			lda result+1
			sta rayProjDist
			lda result+2
			sta rayProjDist+1

; --------------------------------------------------------------------------------
;                                 MANAGE COLORS
; --------------------------------------------------------------------------------

			ldx rayMapY					; Y=column of the map
			ldy rayMapX					; X=row of the map 
			jsr getCellColor			; A = color

			; If intersection is at Y axis then use alternate color

			ldy raySide
			cpy #1						; If ray hits the Y axis then use shader
			beq rayBuffering_keepColor
	
			; Use shaders

			tax							; A register contains the color code
			lda shaders,x
  
rayBuffering_keepColor 	ldy rayCounter
			sta colorBuffer,y  


; --------------------------------------------------------------------------------
;                                       INTERPOLATE
; --------------------------------------------------------------------------------

			tya							; Y register contains rayCounter
			asl							; i = rayCounter * 2
			tay							; n = rayCounter * 2

			; Always save the actual ray
	
			lda rayProjDist				; zBuffer(i) = rayProjDist
			sta zBuffer_lo,y			; zBuffer(i+1) = rayProjDist
			sta zBuffer_lo+1,y
			lda rayProjDist+1
			sta zBuffer_hi,y
			sta zBuffer_hi+1,y
	
			; Prepare to calculate interpolated element i-1

			dey							; If rayCounter = 0 then save info and exit
			bmi rayBuffering_exit					; i = i - 1
			
			; If ray hits the same wall then use delta
			
			lda raySide					; If wall that actual ray hits is not the same
			cmp rayBuffering_hotSide				; as hot side then exit.
			beq rayBuffering_sameSide
			
			; If we are hitting the corner then don't use delta
			
			lda rayMapX
			cmp rayBuffering_hotWallX
			beq rayBuffering_exit
			
			lda rayMapY
			cmp rayBuffering_hotWallY
			beq rayBuffering_exit
		
			jmp rayBuffering_notSame
	
			; If we are hitting the same wall
			
rayBuffering_sameSide	lda rayMapX					; Check if actual ray map cell X position
			cmp rayBuffering_hotWallX				; is same as previous ray map cell X position.
			beq rayBuffering_sameX	
	
			lda rayMapY					; Check if actual ray map cell Y position
			cmp rayBuffering_hotWallY				; is same as previous ray map cell Y position.
			bne rayBuffering_notSame

rayBuffering_sameX		lda rayProjDist				; Delta = (ProjDist - ZBuffer(i)) / 2			
			sec 						; Calculate delta as difference between
			sbc zBuffer_lo,y			; actual ray projected distance and
			sta rayBuffering_delta						; previous ray projected distance.
			lda rayProjDist+1				
			sbc zBuffer_hi,y
			sta rayBuffering_delta+1

			asl							; If Delta is negative then MSB will be 1
			ror rayBuffering_delta+1				; Presarve negative sign to cary with asl
			ror rayBuffering_delta					; Delta = Delta / 2

rayBuffering_notSame	lda zBuffer_lo,y			; zBuffer(i) = zBuffer(i) + Delta
			clc
			adc rayBuffering_delta
			sta zBuffer_lo,y	
			lda zBuffer_hi,y
			adc rayBuffering_delta+1 
			sta zBuffer_hi,y
	
			; Save data for the interpolation calculaton at the next scan (cells hit by the ray stay hot)

rayBuffering_exit		lda rayMapX					; Save actual ray map cell X value
			sta rayBuffering_hotWallX				; to the local mapCellX variable.
	
			lda rayMapY					; Save actual ray map cell Y value
			sta rayBuffering_hotWallY				; to the local mapCellY variable.
		
			lda raySide					; Save actual ray wall hit side
			sta rayBuffering_hotSide				; to the local wallSide variable.

			rts
	

; Static variables

rayBuffering_delta		!word 0						; Delta
rayBuffering_hotWallX	!byte 0						; Previous ray hit cell X position
rayBuffering_hotWallY	!byte 0						; Previous ray hit cell Y position
rayBuffering_hotSide	!byte 0						; Previous ray hit wall side.

			

; --------------------------------------------------------------------------------
;                                        BUFFERS
; --------------------------------------------------------------------------------

colorBuffer:	!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

	
zBuffer_lo				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

zBuffer_hi				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	


