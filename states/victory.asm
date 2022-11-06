st_Victoly:
    JSR Sprite_Init
    ;Clear screen for grand finale...
    VBLANK
    SET_SDLEN $f100, $0000, $2020
    JSR VRAM_Burst_SquareXfer
    
    VBLANK
    ;Map ending screen
	LDA #BANK(Ending_bg)
	TAM #2
	LDA #BANK(Ending_bg) + 1
	TAM #3
	LDA #BANK(Ending_bg) + 2
	TAM #4
	LDA #BANK(Ending_bg) + 3
	TAM #5

    SET_SDLEN Ending_pal, $0000, 3 * 16 * 2
	JSR Palette_Burst_Xfer

    ;Load BG/Tiles
	SET_SDLEN Ending_bg, $0000, SIZEOF(Ending_bg)
	JSR VRAM_Burst_Xfer
	SET_SDLEN Ending_data, $2000, SIZEOF(Ending_data)
	JSR VRAM_Burst_Xfer
    
    LDA #11	;Play end theme
	STA	<_dh
    LDA #1
	sta	<_al
	stz	<_ah
	JSR	psg_bios

    LDX #180
.victolyWait1:
    PHX
    VBLANK
    PLX
    DEX
    BNE .victolyWait1

    SET_SDAB _TEXT_Victoly, $01A4, SIZEOF(_TEXT_Victoly), $f100
    JSR Buffer_PutText   
    SET_SDAB _TEXT_Victoly, $01C4, SIZEOF(_TEXT_Victoly), $f160
    JSR Buffer_PutText

    LDY #14
    LDX #0
.endgameloop
    PHX
    VBLANK
    PLX
    DEX
    BNE .endgameloop
    DEY
    BNE .endgameloop
    
    LDA #19	;Fade bgm out...
	STA	<_dh
    LDA #15
	sta	<_al
	stz	<_ah
	JSR	psg_bios
    
    LDX #0
.endgameloop2
    PHX
    VBLANK
    PLX
    DEX
    BNE .endgameloop2

    JMP RESET