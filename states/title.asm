;**************************
;*** TITLE Screen logic ***
;**************************
st_Title:
    LDA Game_State
    AND #%0000_0001
    BEQ .init
    JMP _st_Title_Next
.init:
    JSR Sprite_Init
    
    SET_SDAB _TEXT_Title, $00aa, SIZEOF(_TEXT_Title), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_Title, $00ca, SIZEOF(_TEXT_Title), $f160
    JSR Buffer_PutText
    VBLANK

    LDA Mouse_PortMap
    AND #%0000_0001
    BEQ .init_joypad

    ;Has mouse
.init_mouse
    LDX #SPRITE_MAX - 1
    LDA #5
    STA Sprite_List, x
    LDA #120
    STA Sprite_Y, x
    LDA #128
    STA Sprite_X, x
    LDA #0
    STA _sprXh
    
    SET_SDAB _TEXT_clickTo, $0128, SIZEOF(_TEXT_clickTo), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_clickTo, $0148, SIZEOF(_TEXT_clickTo), $f160
    JSR Buffer_PutText
    BRA .init_end

.init_joypad
    SET_SDAB _TEXT_PushRun, $0128, SIZEOF(_TEXT_PushRun), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_PushRun, $0148, SIZEOF(_TEXT_PushRun), $f160
    JSR Buffer_PutText
    VBLANK

.init_end
    INC Game_State 
    LDA #3
    STA Game_ScoreMax

_st_Title_Next:
    INC LFSR_Seed
    JSR Read_Joypads
    
    LDA Mouse_PortMap
    AND #%0000_0001
    BEQ .controller
.mouse
    LDX #3
    JSR Title_Update_Pointer
    LDA Gamepad
    AND #%0000_0010 ;Button II / RUN
    BEQ .end
    INC Game_State
    BRA .end
.controller
    LDA Gamepad
    AND #%0000_1010 
    BEQ .end
    INC Game_State
.end
    RTS

;Todo: title screen menu for mouse & controller to pick 1p/2p and max score
    
Title_Update_Pointer:
    LDA Mouse_X
    CLC
    ADC _sprX, x
    STA <_al
    
    LDA Mouse_X
    EXTSIGN
    ADC _sprXh, x
    STA <_ah

.clamp1   
    CMPSIGN16 <_ax, #0
    BMI .clampL ;X < 0
    CMPSIGN16 <_ax, #256
    BPL .clampR
    LDA <_al
    BRA .next
.clampR
    LDA #$ff
    BRA .next
.clampL
    LDA #0
.next
    STA _sprX, x
    
    
    LDA Mouse_Y
    CLC
    ADC _sprY, x
    STA <_al
    
    LDA Mouse_Y
    EXTSIGN
    ADC _sprYh, x
    STA <_ah

.clamp2 
    CMPSIGN16 <_ax, #0
    BMI .clampU ;X < 0
    CMPSIGN16 <_ax, #224
    BPL .clampD
    LDA <_al
    BRA .end
.clampD
    LDA #224
    BRA .end
.clampU
    LDA #0
.end  
    STA _sprY, x
    RTS
