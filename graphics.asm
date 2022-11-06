;graphics.asm
;Todo: shadow VDC regs; unsafe with VBlank

;len, ctrl, addr, #src, x = queuepos
 .MACRO SET_VRAM_XFER
 .IF (\# != 4)
    .fail
 .ENDIF
    LDA \1
    STA <_VBuf_Length, x
    LDA \2
    STA <_VBuf_Ctrl, x
    
    LDA \3
    STA <_VBuf_AddrL, x
    LDA \3 + 1
    STA <_VBuf_AddrH, x
    
    LDA #LOW(\4)
    STA <_VBuf_SrcL, x
    LDA #HIGH(\4)
    STA <_VBuf_SrcH, x
    
    .ENDM
    
VDC_INC01 = %000_00_000
VDC_INC20 = %000_01_000
VDC_INC40 = %000_10_000
VDC_INC80 = %000_11_000

TEXT_OFFSET         = $0100 ;Tile # where the ASCII table starts (actual font at x + $30)

;Copies ROM to VRAM immediately
;s = source, d = destination, a = length (bytes)
VRAM_Burst_Xfer:
    LDA <_al
    AND #%0000_0001
    BNE .end ;Safety check -- length must be a multiple of 2 as we're writing words.
    
    ;ST0 #0
    SETREG #0
    LDA <_dl
    STA $0002
    LDA <_dh
    STA $0003
    ;ST0 #2
    SETREG #2

    LDY #0
.copy1
    LDA [<_sx], y
    STA $0002
    INY
    LDA [<_sx], y
    STA $0003
    INY
    BNE .copy1
    INC <_sh
    DEC <_ah
    BNE .copy1

    LDX <_al
    BEQ .end
.copy2:
    LDA [<_sx], y
    STA $0002
    INY
    DEX
    LDA [<_sx], y
    STA $0003
    INY
    DEX
    BNE .copy2
.end:    
    RTS

;Copies ROM to VCE RAM immediately
;s = source, d = destination, al = length MAX 256
Palette_Burst_Xfer:
    LDA <_dl
    STA $0402
    LDA <_dh
    STA $0403
    LDY #0
.copy:
    LDA [<_sx], y
    STA $0404
    INY
    LDA [<_sx], y
    STA $0405
    INY
    CPY <_al
    BNE .copy
    RTS
    
Palette_Burst_ReadOut:
    LDA VDC_FadeCursor
    ASL A
    ASL A
    ASL A
    ASL A
    TAX
    STX $0402
    LDA #0
    ROL A
    STA $0403
    BEQ .readLo
    
    ;Laziness...
.readHi
    LDY #16
.readHi2
    LDA $0404
    STA PAL_Buffer + 512, x
    LDA $0405
    AND #%0000_0001
    STA PAL_Buffer + 512 + 256, x
    INX
    DEY
    BNE .readHi2
    BRA .endIteration

.readLo
    LDY #16
.readLo2
    LDA $0404
    STA PAL_Buffer, x
    LDA $0405
    AND #%0000_0001
    STA PAL_Buffer + 256, x
    INX
    DEY
    BNE .readLo2
.endIteration:
    INC VDC_FadeCursor
    LDA VDC_FadeCursor
    CMP #32
    BCC .end
    STZ VDC_Fade    ;Reading palette ok!
.end
    RTS
    
Palette_Fade_Step:
    LDX #0
.loop
    
;<_ax = number of palettes, <_bx = palette offset
Palette_Burst_FadeOut:
    LDA <_al
    ASL A
    ASL A
    ASL A
    ASL A
    TAX
    LDA #0
    ROL A
    BEQ .lo
.hi

.lo
    LDA PAL_Buffer + 256, x
    CMP VDC_FadeTarget
    RTS

;<dx = VRAM dest. address. <ax = length (x/y)
;<sx = Tile + Attributes;
VRAM_Burst_SquareXfer:
    LDY <_sh
    
.nextrow
    ;Set row target address in VRAM
    ;ST0 #0
    SETREG #0
    LDA <_dl
    STA $0002
    LDA <_dh
    STA $0003
    SETREG #2

    LDA <_sl
    LDX <_al ;X bytes
.copy
    STA $0002
    STY $0003
    DEX
    BNE .copy
    
    LDA #$20    ;32x32 bat only.
    CLC
    ADC <_dl
    STA <_dl
    LDA #0
    ADC <_dh
    STA <_dh
    
    DEC <_ah   
    BNE .nextrow
.end:    
    RTS

;Perform writes in buffer. Length is in words (length=1, bytes=2)
;Length value 00 (STOP) is the only way to reject the contents of the buffer in a run.
;Format:  09       00      00 20      00 80               ... 00
;        (length) (ctrl)  (VDC Addr) (SRC Addr/Literal)  ... (next buffer write or STOP -- length = 0)
;         Control bits:
;                  00 Repeat 16-bit Literal       (len) (Addr) (Literal)
;                  01 Replicate data from Source  (len) (Addr) (SrcAddr)
;                  11 ???
;           XXX0_0XXX Set VRAM increment length 
;              0_0   +1
;              0_1   +20 etc.
;Transfers until Xfer_Max_Bytes is reached, then copies remainder of buffer to beginning.
;Note: this is pure busywork since PCE can access VRAM at active display
;however there are some situations in which writing only in vblank is good.
_Xfer_Cursor    = _ibx
VRAM_Buffer_Xfer:
    STZ <_Xfer_Cursor
.xferloop:
    LDX <_Xfer_Cursor
    LDA <VDC_Buffer, x
    BNE .xferloop.2
    ST0 #5
    LDA #VDC_INC01
    STA $0003
    STZ <VDC_Buffer ;"Clear" buffer
    RTS ;Nothing else to process
.xferloop.2:
    ;Load control code
    ST0 #5
    LDA <VDC_Buffer + 1, x
    AND #%0001_1000
    STA $0003

    ;Write from CPU to VDC
    ST0 #0
    LDA <VDC_Buffer + 2, x
    STA $0002
    LDA <VDC_Buffer + 3, x
    STA $0003
    LDA <VDC_Buffer + 4, x
    STA <_ial    ;VDC_PTR_A
    LDA <VDC_Buffer + 5, x
    STA <_iah    ;VDC_PTR_A + 1

    ST0 #2
    LDA <VDC_Buffer + 1, x
    LSR A
    BCC .xferloop.repeat
    ;LSR A
    ;BCS .xferloop.????
    
    LDA <VDC_Buffer, x
    TAX
    LDY #0
.xferloop.copy_Start:
    LDA [<_iax], y  ; [VDC_PTR_A], y
    STA $0002
    INY
    LDA [<_iax], y  ; [VDC_PTR_A], y
    STA $0003
    INY
    DEX
    BNE .xferloop.copy_Start
.xferloop.nextCommand:
    LDA <_Xfer_Cursor
    CLC
    ADC #6
    STA <_Xfer_Cursor
    JMP .xferloop

.xferloop.repeat:
    LDA <VDC_Buffer, x
    TAX
    LDA <_ial
    LDY <_iah
.xferloop.repeat_Start:
    STA $0002
    STY $0003
    DEX
    BNE .xferloop.repeat_Start
    JMP .xferloop.nextCommand

;<sx = ASCII text source. <dx = VRAM dest. address. <ax = length
;<bh = Tile high byte; <_bl = Offset
;
_TextXfer_Cursor    = _cl
Buffer_PutText:
    JSR VRAM_Buffer_Next
    CPX #$ff
    BEQ .err
    TXA
    CLC
    ADC <_al
    CMP #SIZEOF(String_Buffer)
    BCC .pass
.err
    RTS ;Cannot write to buffer
.pass: 
    SET_VRAM_XFER <_al, #%0000_0001, <_dx, String_Buffer
    STZ <_VBuf_Terminator, x

    JSR Text_Buffer_Next
    TYA

    ;Macro no worky :(	
    CLC
	ADC <_VBuf_SrcL, x
	STA <_VBuf_SrcL, x
	LDA #0
	ADC <_VBuf_SrcH, x
	STA <_VBuf_SrcH, x
   ; ADC16 <_VBuf_SrcL, x

    SXY     ;X = Text_Buffer cursor (16-bit)
    LDY #0  ;Y = Source cursor (8-bit)
.copy:
    ;Low byte: ASCII charcode
    LDA [_sx], y
    CLC
    ADC <_bl
    STA String_Buffer, x
    ;High byte: VRAM index + Palette
    LDA <_bh
    ADC #0
    STA String_Buffer + 1, x
    INX
    INX
    INY
    CPY <_al
    BNE .copy
    STZ String_Buffer, x
    RTS


;Finds next vacant spot in the write buffer, passes index through X
VRAM_Buffer_Next:
    LDX #0
.loop
    LDA <VDC_Buffer, x
    BEQ .found
    TXA
    CLC
    ADC #6
    TAX
    CPX #SIZEOF(VDC_Buffer)
    BCC .loop
    LDX #$ff ;Not found
.found
    RTS

Text_Buffer_Next:
    LDY #0
.loop
    LDA String_Buffer, y
    BEQ .found
    INY
    CPY #SIZEOF(String_Buffer)
    BCC .loop
    LDY #$ff
.found
    RTS