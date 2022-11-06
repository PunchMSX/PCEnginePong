;init.asm
;PCE specific initialization code

VDC_Setup:
	ST0 #09	;
	ST1 #%0000_0000 ;32x32 nametable in VRAM
	ST2 #%0000_0000

	;Screen setup: 256x240
	;Vertical
	ST0 #$0C	;Video Display pulse Width and poSition
	ST1 #2
	ST2 #15		;Graphic display starts at vblank+1

	ST0 #$0D		;Video Display Width
	ST1 #LOW(240-1)
	ST2 #HIGH(240-1) ;224 scanlines

	ST0 #$0E		;Video display CROP reg.
	ST1 #12		;Generic 36 scanline blanking after
	ST2 #00		;all graphics scanlines are displayed.
				;Not having this is what makes that funky "splitscreen" eff.

	;Horizontal
	;HBlank equals 100 cpu cycles if width=240 hdw=$1D
	;This can be important for bike game!
	ST0 #$0A
	ST1 #2	;Don't care
	ST2 #02	;Start scanline at hdot 16

	ST0 #$0B
	ST1 #31	;Draw 256 graphical dots (n/8 +1)
	ST2 #4	;Don't care

	ST0 #$0F			;Set auto-SATB DMA
	ST1 #%0001_0000
	ST2 #0

	;Reset scroll to 0, 0
	ST0 #08	;Y
	ST1 #0
	ST2 #0
	ST0 #07	;X
	ST1 #0
	ST2 #0

	;Set RCR interrupt out of display area (<=64)
	ST0 #06
	ST1 #0
	ST2 #0

	ST0 #$13
	ST1 #LOW($7f00)	;Set VRAM->SATB copy area
	ST2 #HIGH($7f00)

	RTS

RESET:
	SEI
	CSH
	CLD
	
	LDA #$FF              	; 0000 ; 2000 ; 4000 ; 6000 ; 8000 ; A000 ; C000 ; E000 ;
	TAM #0					; I/O  ; RAM  ; GFX1 ; GFX2 ; !GFX        ; PSGD ; PRG0 ;
	LDA #$F8
	TAM #1
	LDA #BANK(Title_bg)
	TAM #2
	LDA #BANK(Title_pal)
	TAM #3

	LDX #$FF
	TXS
	
	LDA $0000	;Clear IRQ1 triggering VDC interrupt flags
	
	LDA #%0000_0111 ; Disable Timer / VBlank / IRQ2 Line interrupts
	STA $1402
	STA $1403
	
	STZ $0C01	; Timer enable off

	STZ $2000
	TII $2000, $2000 + 1, $1fff	;Clear RAM

	ST0 #05
	ST1 #%0000_0100	;Burst On.
	ST2 #%0000_0000

	JSR VDC_Setup
	
	JSR Read_Joypads

	;Clear VRAM
	ST0 #0
	ST1 #LOW($0000)
	ST2 #HIGH($0000)
	ST0 #2
	LDX #0
	LDY #80
.clearVRAM:
	ST1 #0
	ST2 #0
	DEX
	BNE .clearVRAM
	DEY
	BNE .clearVRAM
	
	;Load BG/Tiles
	SET_SDLEN Title_bg, $0000, VRAM_TXSIZE
	JSR VRAM_Burst_Xfer
	
	;Load BG/Tiles
	;SET_SDLEN Game_bg, $0000, SIZEOF(Game_bg)
	;JSR VRAM_Burst_Xfer
	;SET_SDLEN Game_bg_data, $2000, SIZEOF(Game_bg_data)
	;JSR VRAM_Burst_Xfer
	
	;Load Sprites
	SET_SDLEN Gal1_Spr1, $6000, VRAM_TXSIZE2
	JSR VRAM_Burst_Xfer

	;Load Font
	SET_SDLEN Font_data, $1300, SIZEOF(Font_data)
	JSR VRAM_Burst_Xfer
	
	;Load Font
	SET_SDLEN Font_data2, $1900, SIZEOF(Font_data2)
	JSR VRAM_Burst_Xfer
	
	;Load palette
	SET_SDLEN Title_pal, $0000, 3 * 16 * 2
	JSR Palette_Burst_Xfer
	SET_SDLEN Font_pal, $00f0, 1 * 16 * 2
	JSR Palette_Burst_Xfer
	;SET_SDLEN Game_bg_pal, $0000, 3 * 16 * 2
	;JSR Palette_Burst_Xfer
	SET_SDLEN Gal_Palette, $0100, 2 * 16 * 2
	JSR Palette_Burst_Xfer

	LDA #%0000_0001 ; Disable Timer / VBlank / IRQ2 Line interrupts
	STA $1402
	STA $1403
	
	ST0 #5
	ST1 #%1100_1000 ;BG/SPR Enable
	ST2 #%0000_0000

	JSR MML_Init

	CLI	;Clear CPU interrupt disable
	
	JMP RESET_END
	
MML_Init:
	LDA #2
	sta	<_dh
	lda	#PSGSYS_BOTH_60
	sta	<_al
	stz	<_ah
	JSR	psg_bios
	
	JSR sngInit
	
	LDA #0
	sta	<_dh
	lda	#0	;0 = timer; 1 = vblank
	sta	<_al
	stz	<_ah
	JSR	psg_bios ;IRQ1 mode can't do tempo? Everything sounds double slow. Doc says #2 call doesn't matter for tempo settings either.
				 ;Aetherbyte's mml2pce.exe might not be built for 1/60 fixed tempo, investigate later.
	
	rts
	
	