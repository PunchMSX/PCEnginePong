;**************************
;*** GameOver screen    ***
;**************************
st_GameOba:
    LDA Game_State
    AND #%0000_0001
    BEQ .init
    JMP st_GameOba_Next
.init
    JSR Sprite_Init
    ;Clear screen for grand finale...
    VBLANK
    SET_SDLEN $f100, $0000, $2020
    JSR VRAM_Burst_SquareXfer
    
    VBLANK
    ;Map ending screen
	LDA #BANK(Game_bg)
	TAM #2
	LDA #BANK(Game_bg) + 1
	TAM #3
	LDA #BANK(Game_bg) + 2
	TAM #4
	LDA #BANK(Game_bg) + 3
	TAM #5

    SET_SDLEN Game_bg_pal, $0000, 3 * 16 * 2
	JSR Palette_Burst_Xfer

    ;Load BG/Tiles
	SET_SDLEN Game_bg, $0000, SIZEOF(Game_bg)
	JSR VRAM_Burst_Xfer
	SET_SDLEN Game_bg_data, $2000, SIZEOF(Game_bg_data)
	JSR VRAM_Burst_Xfer
    
    ;Setup Right Gal
    LDX #_OBJ_P1
    LDA #2
    STA Sprite_List, x
    LDA #LVL_BOT - GAL_TALL
    STA Sprite_Y, x
    LDA #128 + 12
    STA Sprite_X, x
    STZ _sprXh, x
    STZ _sprYh, x

    ;Setup Left Gal
    LDX #_OBJ_P2
    LDA #0
    STA Sprite_List, x
    LDA #LVL_BOT - GAL_TALL
    STA Sprite_Y, x
    LDA #128 - 12
    STA Sprite_X, x
    STZ _sprXh, x
    STZ _sprYh, x

    INC Game_State
    STZ Game_ServeTimer
    STZ Game_ServeTimer + 1
    RTS
    
st_GameOba_Next:
    INC16 Game_ServeTimer
    CMPSIGN16 Game_ServeTimer, #60*3 + 1
    BMI .animateHit
    
.endgame
    SET_SDAB _TEXT_GameOba, $0128, SIZEOF(_TEXT_GameOba), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_GameOba, $0148, SIZEOF(_TEXT_GameOba), $f160
    JSR Buffer_PutText

    LDX #180
.endgameloop
    PHX
    VBLANK
    PLX
    DEX
    BNE .endgameloop
    JMP RESET

.animateHit  
    LDA Game_ServeTimer
    AND #%0000_0001
    BNE .animateKick
    LDA Sprite_X + _OBJ_P1
    EOR #%0000_0011
    STA Sprite_X + _OBJ_P1
.animateKick
    LDA Game_ServeTimer
    AND #%0000_0011
    BNE .end
    LDA Sprite_List + _OBJ_P2
    EOR #%0000_0001
    STA Sprite_List + _OBJ_P2
    
.end
    RTS