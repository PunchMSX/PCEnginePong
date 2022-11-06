_st_Title   = 0
_st_Game    = _st_Title + 2
_st_Victoly = _st_Game + 2
_st_GameOba = _st_Victoly + 2

    .include "states/victory.asm"
    .include "states/gameover.asm"
    .include "states/title.asm"
    
;**************************
;*** Pong         logic ***
;**************************
st_Game:
    LDA Game_State
    AND #%0000_0001
    BEQ .init
    JMP st_Game_Next
.init
    JSR Sprite_Init
    
    VBLANK
    SET_SDLEN $f100, $0042, $181c
    JSR VRAM_Burst_SquareXfer
    
    VBLANK
    SET_SDLEN $f1be, $0050, $1801
    JSR VRAM_Burst_SquareXfer
    
    VBLANK
    SET_SDLEN $f15e, $004f, $1801
    JSR VRAM_Burst_SquareXfer

    VBLANK
    STZ Game_Score
    STZ Game_Score + 1
    JSR Game_DrawScores

    ;Setup Right Gal
    LDX #_OBJ_P1
    LDA #2
    STA Sprite_List, x
    LDA #114
    STA Sprite_Y, x
    LDA #256 - 32
    STA Sprite_X, x
    STZ _sprXh, x
    STZ _sprYh, x

    ;Setup Left Gal
    LDX #_OBJ_P2
    LDA #0
    STA Sprite_List, x
    LDA #114
    STA Sprite_Y, x
    STA AI_Pos_Y + 1
    STZ AI_Pos_Y
    LDA #32
    STA Sprite_X, x
    STZ _sprXh, x
    STZ _sprYh, x

    LDA #3
    STZ Game_ServeTimer + 1
    STZ Game_ServeTimer     ;Ball moves only when timer > opp_wait

    LDA #_OBJ_P2
    STA Game_LastScorer     ;Allow player to serve at start

    STZ Game_DrawText       ;Used to show Serve!/Ready! text.

    LDA #1
    STA Ball_SpeedMultiplier

    INC Game_State
    
    LDA #11	;Play Karnov's national anthem
	STA	<_dh
    LDA #0
	sta	<_al
	stz	<_ah
	JSR	psg_bios
    
    RTS
    

;*******************************************************************************
; Game loop -- pong game logic runs here.
;*******************************************************************************
_OBJ_P1   = 0
_OBJ_P2   = 1
_OBJ_BALL = 2

LVL_TOP    = 16
LVL_BOT    = 208
LVL_LEFT   = 16
LVL_RIGHT  = 240
BALL_RAD   = 8
GAL_TALL   = 40
GAL_THIC   = 16
st_Game_Next:
    JSR Read_Joypads
    
;************Check if game ended**************
    LDX Game_LastScorer
    LDA Game_Score, x
    CMP Game_ScoreMax
    BCC .cont
    
    LDA #19	;Fade bgm out...
	STA	<_dh
    LDA #15
	sta	<_al
	stz	<_ah
	JSR	psg_bios
    
    LDX #0
.gameEnd
    PHX
    VBLANK
    PLX
    DEX
    BNE .gameEnd
    LDA Game_LastScorer
    CMP #_OBJ_P1
    BNE .gameLost
.gameWon
    LDA #_st_Victoly
    STA Game_State
    RTS
.gameLost
    LDA #_st_GameOba
    STA Game_State
    RTS

;****************Game Loop*****************
.cont
    LDA #LVL_TOP + GAL_TALL
    STA <_al
    LDA #LVL_BOT - GAL_TALL
    STA <_bl
    STZ <_ah
    STZ <_bh
    LDX #0
    
    LDA Mouse_PortMap
    AND #%0000_0001
    BEQ .controllerChara
.mouseChara
    JSR Game_MouseCharacter
    BRA .brkpt
.controllerChara
    JSR Game_JoypadCharacter
    
.brkpt
    CMPSIGN16 Game_ServeTimer, #OPPONENT_WAIT + 1
    BPL .gameisOn

.serving
    LDA Game_LastScorer
    CMP #_OBJ_P1
    BEQ .oppServing
    JSR Game_PlayerServe
    BRA .end

.oppServing
    JSR Game_AIServe
    BRA .end

.gameisOn
    JSR Game_AICharacter
    JSR Game_ProcessBall

.end
    RTS
    
;*******************************************************************************
; Draws scoreboard.
;*******************************************************************************
Game_DrawScores:
    ;Hacky way of drawing the score.
    SET_SDAB Game_Score, $00b3, 1, $f130
    JSR Buffer_PutText  
    SET_SDAB Game_Score, $00d3, 1, $f190
    JSR Buffer_PutText
    
    SET_SDAB Game_Score + 1, $00ac, 1, $f130
    JSR Buffer_PutText  
    SET_SDAB Game_Score + 1, $00cc, 1, $f190
    JSR Buffer_PutText
    
    RTS
    
;*******************************************************************************
; Process ball physics and scoring.
;*******************************************************************************
Game_ProcessBall:
    ;fractionary part
    LDA Ball_Pos_Y
    CLC
    ADC Ball_Speed_Y
    STA Ball_Pos_Y
    
    LDA Ball_Speed_Y + 1
    ADC Ball_Pos_Y + 1
    STA <_al
    LDA Ball_Speed_Y + 1
    EXTSIGN
    ADC #0
    STA <_ah
    
    ;Collide with screen
    CMPSIGN16 <_ax, #(LVL_TOP + BALL_RAD)
    BMI .rtop
    CMPSIGN16 <_ax, #(LVL_BOT - BALL_RAD)
    BPL .rbot
    LDA <_al
    STA _sprY + _OBJ_BALL
    STA Ball_Pos_Y + 1
    BRA .processX
.rtop
    LDA #LVL_TOP + BALL_RAD ;The physically correct way would be to subtract the distance to top
                            ;from Y for the full ball path, but glueing ball to top shows CONTACT.
    BRA .ry
.rbot
    LDA #LVL_BOT - BALL_RAD 
.ry
    STA _sprY + _OBJ_BALL
    STA Ball_Pos_Y + 1
    NEG16 Ball_Speed_Y
    STA Ball_Speed_Y + 1
    STX Ball_Speed_Y

.processX
    ;fractionary part
    LDA Ball_Pos_X
    CLC
    ADC Ball_Speed_X
    STA Ball_Pos_X
    
    LDA Ball_Speed_X + 1
    ADC Ball_Pos_X + 1
    STA <_al
    STA Ball_Pos_X + 1
    LDA Ball_Speed_X + 1
    EXTSIGN
    ADC #0
    STA <_ah
    JSR CheckBallCollision
    ;CMP #0
    ;BEQ .noCollisionx
.collisionx
    ;LDA _sprX, x   ;Snapping the Ball X to the paddle doesn't look as good though.
    ;BRA .end
.noCollisionx
    ;LDA <_al ;This gets corrupted!! Watch out.
.end
    LDA Ball_Pos_X + 1
    STA _sprX + _OBJ_BALL
    RTS
    
    

;**************Ball collision detection checks***************
CheckBallCollision:
    LDA Ball_Speed_X + 1
    BPL .right
.left
    CMPSIGN16 <_ax, #(LVL_LEFT + BALL_RAD)
    BMI .p1scores
    CMPSIGN16 <_ax, #(LVL_LEFT + GAL_THIC + BALL_RAD)
    BMI .oppPadArea
    BRA .end
.right
    CMPSIGN16 <_ax, #(LVL_RIGHT - BALL_RAD)
    BPL .oppscores
    CMPSIGN16 <_ax, #(LVL_RIGHT - GAL_THIC - BALL_RAD)
    BPL .p1PadArea
.end
    LDA #0
    RTS
    
.oppPadArea:
    LDX #_OBJ_P2
    BRA .padCheck
.p1PadArea:
    LDX #_OBJ_P1
    
.padCheck:
    LDA _sprY, x
    SEC
    SBC #(GAL_TALL + BALL_RAD)   ;No overflow since we limit the obj Y axis
    CMP Ball_Pos_Y + 1
    BCS .end ;Pad top above ball
    LDA _sprY, x
    CLC
    ADC #(GAL_TALL + BALL_RAD)
    CMP Ball_Pos_Y + 1
    BCC .end ;Pad bottom above ball

    PHX
    JSR Game_PadReflect
    
    LDA #11	;Play hit sfx
	STA	<_dh
    LDA Ball_Speed_X+1
    BMI .playboop
.playbeep
    LDA #2
    BRA .play
.playboop
    LDA #3
.play
	sta	<_al
	stz	<_ah
	JSR	psg_bios

    PLX
    LDA #$ff
    RTS

.p1scores:
    LDX #_OBJ_P1
    STX Game_LastScorer
    JSR Game_PlayerScored
    BRA .end
.oppscores:
    LDX #_OBJ_P2
    STX Game_LastScorer
    JSR Game_PlayerScored
    BRA .end

Game_PlayerScored:
    INC Game_Score, x
    STX Game_LastScorer
    
    STZ Game_ServeTimer
    STZ Game_ServeTimer + 1
    
    STZ Game_DrawText
    
    VBLANK
    JSR Game_DrawScores
    RTS
    
;Changes ball X/Y movement vector according to area of paddle hit (8 sections)
;and reflects ball X direction accordingly.
Game_PadReflect:
    LDA Ball_SpeedMultiplier
    INC A
    CMP #8
    BCC .a
    LDA #7  
.a
    STA Ball_SpeedMultiplier
    
    LDA Ball_Pos_Y + 1
    CLC
    ADC #GAL_TALL
    SEC
    SBC _sprY, x
    ;Project ball into paddle local coordinates
    ;We can get away with this since both Y coords are 8-bit unsigned.
.pos
    LDX #0
    
    ;Account for when ball Y < 0 (centrepoint doesn't need to be inside pad for collision!)
    CMP #(256 - BALL_RAD)   ;This doesn't work if world coords don't fit 1 byte :p
    BCS .pos2
    
    CMP #(GAL_TALL / 4)     ;top section 1
    BCC .pos2
    
    INX
    CMP #(GAL_TALL / 4) * 3 ;sections 2, 3
    BCC .pos2
    
    INX
    CMP #(GAL_TALL / 4) * 4 ;middle top, section 4
    BCC .pos2
    
    INX
    CMP #(GAL_TALL / 4) * 5 ;middle bottom, section 5
    BCC .pos2
    
    INX
    CMP #(GAL_TALL / 4) * 7 ;sections 6, 7
    BCC .pos2
    
    INX                     ;section 7
    
.pos2
    LDA Table_PadReflectY, x
    CLC
    ADC Ball_SpeedMultiplier
    TAY
    
    LDA Vector_Fraction_Table, y
    STA Ball_Speed_Y
    LDA Vector_Angle_Table, y
    STA Ball_Speed_Y + 1
    
    LDA Table_PadReflectX, x
    CLC
    ADC Ball_SpeedMultiplier
    TAY

    LDA Ball_Speed_X + 1
 PHA
    LDA Vector_Fraction_Table, y
    STA Ball_Speed_X
    LDA Vector_Angle_Table, y
    STA Ball_Speed_X + 1
 PLA
    BMI .end ;If ball's prev X dir was positive, new dir must be negative.
    
.negX
    NEG16_v2 Ball_Speed_X
    ;STA Ball_Speed_X + 1
    ;STX Ball_Speed_X
    
.end
    RTS


;From top to bottom of the pad, 5 areas
Table_PadReflectX:
    .db A_X60, A_X45, A_X30, A_X30, A_X45, A_X60
Table_PadReflectY:
    .db A_Y300, A_Y315, A_Y330, A_Y30, A_Y45, A_Y60


st_Game_SpawnBall:
    LDA #1
    STA Ball_SpeedMultiplier
    STZ AI_Speed_Y
    STZ AI_Speed_Y + 1
    ;Spawn ball at gal.
    LDA #4
    STA Sprite_List + _OBJ_BALL
    
    LDA _sprX, x
    STA _sprX + _OBJ_BALL
    STA Ball_Pos_X + 1
    STZ Ball_Pos_X  ;fraction
    LDA _sprXh, x
    STA _sprXh + _OBJ_BALL
    
    LDA _sprY, x
    SEC
    SBC #8
    STA _sprY + _OBJ_BALL
    STA Ball_Pos_Y + 1
    STZ Ball_Pos_Y  ;fraction
    LDA _sprYh, x
    SBC #0
    STA _sprYh + _OBJ_BALL
    
    ;STZ Ball_SpeedMultiplier

    RTS

Game_AIServe:
    LDX #_OBJ_P2
    JSR st_Game_SpawnBall
    
    LDA Game_DrawText
    BNE .tick
.init
    SET_SDAB _TEXT_Ready, (12 * 32 + 8), SIZEOF(_TEXT_Ready), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_Ready, (13 * 32 + 8), SIZEOF(_TEXT_Ready), $f160
    JSR Buffer_PutText
    INC Game_DrawText
    BRA .end
.tick
    INC16 Game_ServeTimer
    LDA Game_ServeTimer + 1
    CMP #HIGH(OPPONENT_WAIT)
    BNE .end
    LDA Game_ServeTimer
    CMP #LOW(OPPONENT_WAIT)
    BNE .end
.serve
    ;Erase on-screen text
    SET_SDLEN $f100, (12 * 32 + 8), $200 + SIZEOF(_TEXT_Ready)
    JSR VRAM_Burst_SquareXfer
    
    LDA #A_Y30
    CLC
    ADC Ball_SpeedMultiplier
    TAY
    
    LDA Vector_Fraction_Table, y
    STA Ball_Speed_Y
    LDA Vector_Angle_Table, y
    STA Ball_Speed_Y + 1
    
    LDA #A_X30
    CLC
    ADC Ball_SpeedMultiplier
    TAY

    LDA Vector_Fraction_Table, y
    STA Ball_Speed_X
    LDA Vector_Angle_Table, y
    STA Ball_Speed_X + 1

    ;Random 30 deg. shot
    JSR LFSR_Next ;get rand
    BMI .end
    NEG16_v2 Ball_Speed_Y
.end
    RTS

Game_PlayerServe:
    LDX #_OBJ_P1
    JSR st_Game_SpawnBall
    
    LDA Game_DrawText
    BNE .check
    SET_SDAB _TEXT_Serve, $0113, SIZEOF(_TEXT_Serve), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_Serve, $0133, SIZEOF(_TEXT_Serve), $f160
    JSR Buffer_PutText
    INC Game_DrawText
    
.check
    LDA Gamepad_Trig
    AND #%0000_0010 ;Player must click to serve
    BNE .serve
    JMP .end2
.serve
    SET_SDLEN $f100, $0113, $100 + SIZEOF(_TEXT_Serve)
    JSR VRAM_Burst_SquareXfer
    SET_SDLEN $f100, $0133, $100 + SIZEOF(_TEXT_Serve)
    JSR VRAM_Burst_SquareXfer
    
    ;Decide ball angle
    ;LDA Mouse_Y
    ;LSR A
    ;LSR A   ;Strength divider
    ;AND #%0000_0111 ;Max speed = vector length 8
    ;TAX
      ;Turns out using mouse speed for shot isn't too fun.
.servedown
    LDA #A_X330
    CLC
    ADC Ball_SpeedMultiplier
    TAY
    LDA Vector_Angle_Table, y ;-30 deg. x
    STA Ball_Speed_X + 1
    LDA Vector_Fraction_Table, y
    STA Ball_Speed_X
    
    ;PHX
    ;NEG16 Ball_Speed_X
    ;PLX
    ;STX Ball_Speed_X
    ;STA Ball_Speed_X + 1

    LDA #A_Y30
    CLC
    ADC Ball_SpeedMultiplier
    TAY
    LDA Vector_Angle_Table + 16, y ;-30 deg. y
    STA Ball_Speed_Y + 1
    LDA Vector_Fraction_Table + 16, y
    STA Ball_Speed_Y
        
    LDA Mouse_Y
    BMI .end
    NEG16 Ball_Speed_Y
    STX Ball_Speed_Y
    STA Ball_Speed_Y + 1
.end
    LDA #LOW(OPPONENT_WAIT)
    STA Game_ServeTimer
    LDA #HIGH(OPPONENT_WAIT) + 1
    STA Game_ServeTimer + 1
.end2
    RTS
    
Game_AIAccel = 64 ; 1/32
Game_AISpeedMax = 3
Game_AICharacter:
    LDA Ball_Pos_Y + 1 
    SEC
    SBC _sprY + _OBJ_P2
    BMI .belowball
.aboveball
    LDA #Game_AIAccel
    ADC16 AI_Speed_Y
    BRA .moveAI
.belowball
    LDA AI_Speed_Y
    SEC
    SBC #Game_AIAccel
    STA AI_Speed_Y
    LDA AI_Speed_Y + 1
    SBC #0
    STA AI_Speed_Y + 1
    
.moveAI
    LDA AI_Pos_Y    ;fraction of Y
    CLC
    ADC AI_Speed_Y  ;fractionary value
    STA AI_Pos_Y

    LDA AI_Speed_Y + 1 ;Full decimals
    ADC AI_Pos_Y + 1
    STA <_cl
    
    LDA AI_Speed_Y + 1
    EXTSIGN
    ADC #0
    STA <_ch
    
    CMPSIGN16 <_cx, <_ax
    BMI .clampU ;X < 0
    CMPSIGN16 <_cx, <_bx
    BPL .clampD
    LDA <_cl
    BRA .end
.clampD
    STZ AI_Speed_Y
    STZ AI_Speed_Y + 1
    LDA <_bl
    BRA .end
.clampU
    STZ AI_Speed_Y
    STZ AI_Speed_Y + 1
    LDA <_al
.end  
    STA _sprY + _OBJ_P2
    STA AI_Pos_Y + 1
    RTS
    
Game_JoypadCharacter:
    STZ Mouse_Y
    
    LDA Gamepad
    AND #%0000_0001 ;Button I
    BEQ .normalspeed
.fastspeed
    LDA #3
    BRA .1
.normalspeed
    LDA #1
.1
    STA <_cl

    LDA Gamepad
    AND #%0100_0000 ;Down
    BNE .down
    LDA Gamepad
    AND #%0001_0000 ;up
    BNE .up
    RTS
.up
    LDA <_cl
    NEG
    STA <_cl ;Laziness is a sin...
.down
    LDA <_cl
    STA Mouse_Y
    
    JSR Game_MouseCharacter ;Piggyback off mouse movement routine
    RTS


;<_ax, <_bx = boundary (top, bottom);
Game_MouseCharacter:
    LDA Mouse_Y
    CLC
    ADC _sprY, x
    STA <_cl
    
    LDA Mouse_Y
    EXTSIGN
    ADC _sprYh, x
    STA <_ch

.clamp 
    CMPSIGN16 <_cx, <_ax
    BMI .clampU ;X < 0
    CMPSIGN16 <_cx, <_bx
    BPL .clampD
    LDA <_cl
    BRA .end
.clampD
    LDA <_bl
    BRA .end
.clampU
    LDA <_al
.end  
    STA _sprY, x
    RTS


_TEXT_Title:    .db "Neo  TorPONG"
_TEXT_PushRun:  .DB "Push ", $5b, $5c, $5d, " button", $5f, $5f
_TEXT_clickTo:  .DB "Click to ", $7b, $7c, $7d, $7e, $7f, $5f, $5f
_TEXT_Serve:    .DB "Serve", $5f
_TEXT_Ready:    .DB "Ready", $5f
_TEXT_GameOba:  .DB "G A M E  O V E R"
_TEXT_Victoly:  .db "You won", $5f, " Conglaturation", $5f, $5f