;Neo TorPONG
;Punch 22/10/2022

 .include "labels.inc"
    .ZP
CPU_Ptr     .ds 2
_ax         .ds 2
_bx         .ds 2
_cx         .ds 2
_dx         .ds 2
_sx         .ds 2

_iax         .ds 2
_ibx         .ds 2
_icx         .ds 2
_idx         .ds 2
_isx         .ds 2

_ar_buf     .ds 1

VDC_Buffer  .ds 64
_VBuf_Length    = VDC_Buffer
_VBuf_Ctrl      = VDC_Buffer + 1
_VBuf_AddrL     = VDC_Buffer + 2
_VBuf_AddrH     = VDC_Buffer + 3
_VBuf_SrcL      = VDC_Buffer + 4
_VBuf_SrcH      = VDC_Buffer + 5
_VBuf_Terminator = VDC_Buffer + 6

_al = _ax
_ah = _al + 1
_bl = _bx
_bh = _bl + 1
_cl = _cx
_ch = _cl + 1
_dl = _dx
_dh = _dl + 1
_sl = _sx
_sh = _sl + 1

_ial = _iax
_iah = _ial + 1
_ibl = _ibx
_ibh = _ibl + 1
_icl = _icx
_ich = _icl + 1
_isl = _isx
_ish = _isl + 1

    .BSS
    ;Interleaved Shadow SATB for ease of loopin'
OAM_X       .ds 128 ;First 64 = low, last 64 = high
OAM_Y       .ds 128
OAM_Pattern .ds 128
OAM_Attr    .ds 128

PAL_Buffer  .ds 1024 ;why :(

SPRITE_MAX  = 4
Sprite_List .ds SPRITE_MAX   ;All this game will ever need...
Sprite_X    .ds SPRITE_MAX * 2
Sprite_Y    .ds SPRITE_MAX * 2 ;Access msb by indexing Sprite_Y + SPRITE_MAX
_sprX = Sprite_X
_sprXh = Sprite_X + SPRITE_MAX
_sprY = Sprite_Y
_sprYh = Sprite_Y + SPRITE_MAX

_VSyncCnt   .ds 1
_TimerCnt   .ds 1
_MainCnt    .ds 1
_SubCnt     .ds 1 ;Squirrel.h defines this.

CPU_Busy    .ds 1
VDC_Busy    .ds 1


VDC_Fade        .ds 1
VDC_FadeTarget  .ds 2
VDC_FadeCursor  .ds 1
VDC_NoFade  = 0
VDC_ReadPal = 1
VDC_FadeOut = 2

Game_State      .ds 1
Game_PrevState  .ds 1

String_Buffer   .ds 64

LFSR_Seed       .ds 1

Gamepad_Toggle  .ds 2
Gamepad         .ds 2
Gamepad_Prev    .ds 2
Gamepad_Trig:	.ds 2
;Mouse_X         .ds 2
;Mouse_Y         .ds 2

Title_ShowMenu  .ds 1

Game_Score      .ds 2
Game_ServeTimer .ds 2   ;Frame, sec.
Game_LastScorer .ds 1   ;0 for player, 1 for opp.
Game_DrawText   .ds 1   ;General text drawn flag.
Game_ScoreMax   .ds 1

Ball_Pos_X        .ds 2
Ball_Pos_Y        .ds 2
Ball_Speed_X      .ds 2   ;8.8 fixed point.
Ball_Speed_Y      .ds 2   ;8.8 fixed point.
Ball_SpeedMultiplier   .ds 1

AI_Speed_Y        .ds 2
AI_Pos_Y          .ds 2

OPPONENT_WAIT = (60 * 3) ;3.00 seconds

 .INCLUDE "macros.asm"
 .INCLUDE "sound.inc"   ;Squirrelly squirrels
 
    .code
    .bank 0, "----- Startup Bank-----"
    .ORG $E000
    
    .INCLUDE "init.asm"
    .INCLUDE "spr.asm"
    .INCLUDE "gamestate.asm"
    .INCLUDE "graphics.asm"
    .INCLUDE "joypad.asm"
    .INCLUDE "math.asm"
    
LFSR_Next:
    LDA LFSR_Seed
    BEQ .1
    ASL
    BEQ .2
    BCC .2
.1    
    EOR #$1D
.2
    STA LFSR_Seed
    RTS
    
RESET_END:
    JSR Sprite_Init
    
;I'd do a jump table AND state machine to manage game state
;but having self-orchestrated loop jumps will have to do.
MainLoop:
    VBLANK
    INC CPU_Busy
    
;game logic here...
    LDA Game_State
    AND #%1111_1110
    CMP #_st_Title
    BNE .a
    JSR st_Title
    BRA .end
.a
    CMP #_st_Game
    BNE .b
    JSR st_Game
    BRA .end
.b
    CMP #_st_Victoly
    BNE .c
    JSR st_Victoly
    BRA .end
.c
    CMP #_st_GameOba
    BNE .end
    JSR st_GameOba

.end
    JSR Update_OAM

    STZ CPU_Busy
    JMP MainLoop

EXTIRQ:
NMI:
    RTI
TIMER:
	PHA ;3
	PHX ;3
	PHY ;3
    STZ $1403
    __sound_timer
    PLY
	PLX
	PLA
    RTI

IRQ1:
	PHA ;3
	PHX ;3
	PHY ;3
    LDA $0000 ;Check status flag & ack interrupt
    
    ;LDA VDC_Fade
    ;CMP #VDC_ReadPal
    ;BEQ .readPal
    ;CMP #VDC_FadeOut
    ;BNE .bufferCheck
    
;.fadeOut
    ;JSR Palette_Burst_FadeOut
    ;BRA .end

;.readPal
    ;JSR Palette_Burst_ReadOut
    ;BRA .end

.bufferCheck
    JSR VRAM_Buffer_Xfer
    STZ String_Buffer ;"Clears" text buffer

.end
    STZ VDC_Busy

    ;__sound_vsync
    ;__sound_vsync

    LDA <_ar_buf
    STA $0000
    PLY
	PLX
	PLA
	RTI

    .include "sngInit.asm"
    .include "sound.asm" ;Orig. PSG_BIOS caller + interrupt handler; + new bank define for PSG BIOS

    .ORG $FFF6
    .dw EXTIRQ
    .dw IRQ1
    .dw TIMER
    .dw NMI
    .dw RESET

    .data
    .bank BANK(psgOn) + 1, "-----Graphics Data-----"
    .page 2
    
Title_bg:   .INCBIN "gfx/title_BAT.bin"
            .INCBIN "gfx/title_DATA.bin"
            
Gal1_Spr1:  .incspr "gfx/sprites.pcx", 0, 0, 2, 4
Gal2_Spr1:  .incspr "gfx/sprites.pcx", 32, 0, 2, 4
Gal1_Spr2:  .incspr "gfx/sprites.pcx", 0, 64, 1, 1
Gal2_Spr2:  .incspr "gfx/sprites.pcx", 32, 64, 1, 1
Gal2_Spr3:  .incspr "gfx/sprites.pcx", 64, 32, 1, 1
Ball:       .incspr "gfx/sprites.pcx", 64, 0, 1, 1

MousePointer:  .incspr "gfx/sprites.pcx", 64, 48, 1, 1

Title_pal:      .INCBIN "gfx/title_PAL.bin"
Font_pal:       .incpal "gfx/font.pcx", 0, 1

Gal_Palette:    .incpal "gfx/sprites.pcx", 0, 1
Gal_Palette2:   .incpal "gfx/sprites.pcx", 1, 1

VRAM_TXSIZE     = Gal1_Spr1 - Title_bg
VRAM_TXSIZE2    = Title_pal - Gal1_Spr1

Font_data:  .incchr "gfx/font.pcx", 16, 5
Font_data2:  .incchr "gfx/font.pcx", 0, 40, 16, 5

    .bank BANK(*) + 1
    .page 2

Game_bg:        .INCBIN "gfx/gamebg_BAT.bin"
Game_bg_data:   .INCBIN "gfx/gamebg_DATA.bin"
Game_bg_pal:    .INCBIN "gfx/gamebg_PAL.bin"

    .bank BANK(*) + 1
    .page 2
Ending_pal:     .incbin "gfx/ending_PAL.bin"
Ending_bg:      .incbin "gfx/ending_BAT.bin"
Ending_data:    .incbin "gfx/ending_DATA.bin"

    .bank BANK(*) + 1, "----- Music data -----"
    .page 4
MML_Multitrack: .include  "mml/multitrack.asm"