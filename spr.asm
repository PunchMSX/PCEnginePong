;spr.asm
;Manages metasprites on a shadow SATB in RAM, and VRAM uploads.

Sprite_Init:
    LDX #SPRITE_MAX
    LDA #$FF
.loop
    DEX
    STA Sprite_List, x
    STZ Sprite_X, x
    STZ Sprite_Y, x
    STZ _sprXh, x
    STZ _sprYh, x
    BNE .loop
    RTS
    
Upload_OAM:
    ST0 #0
    ST1 #0
    ST2 #$7f

    ST0 #2
    LDX #0
.loop
    LDA OAM_Y, x
    STA $0002
    LDA OAM_Y + 64, x
    STA $0003
    LDA OAM_X, x
    STA $0002
    LDA OAM_X + 64, x
    STA $0003
    LDA OAM_Pattern, x
    STA $0002
    LDA OAM_Pattern + 64, x
    STA $0003
    LDA OAM_Attr, x
    STA $0002
    LDA OAM_Attr + 64, x
    STA $0003
    
    INX
    CPX #64
    BNE .loop

Update_OAM:
_UOA_SprCount = _ax
_UOA_MSIndex = _bx
_UOA_MSPosX = _cx
_UOA_MSPosY = _sx
_UOA_OAMPtr = _dx
    LDX #$FF
    STX <_UOA_MSIndex
    STZ <_UOA_OAMPtr
.forEachSpr:
    INC <_UOA_MSIndex
    LDX <_UOA_MSIndex
    CPX #SPRITE_MAX
    BNE .cont
    
    LDX <_UOA_OAMPtr
.end
    STZ OAM_X, x
    STZ OAM_X + 64, x
    STZ OAM_Y, x
    STZ OAM_Y + 64, x
    STZ OAM_Pattern, x
    STZ OAM_Pattern + 64, x
    STZ OAM_Attr, x
    STZ OAM_Attr + 64, x
    INX
    CPX #64
    BNE .end
    RTS
    
.cont
    LDA Sprite_List, x
    CMP #$ff
    BEQ .forEachSpr
    ASL
    TAY

    LDA Metasprite_Table, y
    STA <CPU_Ptr
    LDA Metasprite_Table + 1, y
    STA <CPU_Ptr + 1
    
    LDA _sprX, x
    CLC
    ADC #32
    STA <_UOA_MSPosX
    LDA _sprXh, x
    ADC #0
    STA <_UOA_MSPosX + 1
    
    LDA _sprY, x
    CLC
    ADC #64
    STA <_UOA_MSPosY
    LDA _sprYh, x
    ADC #0
    STA <_UOA_MSPosY + 1

    LDY #0
    LDA [CPU_Ptr], y
    STA <_UOA_SprCount
    STX <_UOA_MSIndex ;Save bx for next metasprite indexing
    LDX <_UOA_OAMPtr
    INY
.updateSpr:
    ;Transform Relative to Screen coords.
    LDA [CPU_Ptr], y
    CLC
    ADC <_UOA_MSPosX
    STA OAM_X, x
    LDA [CPU_Ptr], y
    EXTSIGN
    ADC <_UOA_MSPosX + 1
    STA OAM_X + 64, x
    
    INY
    LDA [CPU_Ptr], y
    CLC
    ADC <_UOA_MSPosY
    STA OAM_Y, x
    LDA [CPU_Ptr], y
    EXTSIGN
    ADC <_UOA_MSPosY + 1
    STA OAM_Y + 64, x

    ;Load pattern # (16-bits)
    INY
    LDA [CPU_Ptr], y
    STA OAM_Pattern, x
    INY
    LDA [CPU_Ptr], y
    STA OAM_Pattern + 64, x
    
    ;Load Attributes
    INY
    LDA [CPU_Ptr], y
    STA OAM_Attr, x
    INY
    LDA [CPU_Ptr], y
    STA OAM_Attr + 64, x
    
    INY
    INX
    ;Go to next sprite in metalist, if able
    DEC <_UOA_SprCount
    BNE .updateSpr
    STX <_UOA_OAMPtr
    JMP .forEachSpr

Metasprite_Table:
    .DW META_GAL1
    .DW META_GAL1b
    .DW META_GAL2
    .DW META_GAL2b
    .DW META_BALL
    .DW META_MOUSE

META_BALL:  .DB 1
            .DB -8, -8                ;X/Y Offset from centrepoint
            .DW $193 * 2              ;Pattern Code
            .DB $80 + 1, %0000_0000   ;Attributes
            
META_MOUSE: .DB 1
            .DB 0, 0                ;X/Y Offset from centrepoint
            .DW $194 * 2              ;Pattern Code
            .DB $80 + 1, %0000_0000   ;Attributes

META_GAL1:  .DB 2
            .DB -16, -40                
            .DW $180 * 2                  
            .DB $80 + 0, %0011_0001     
            
            .DB -16, 24
            .DW $190 * 2 
            .DB $80 + 0, %0000_0000
            
META_GAL1b: .DB 3
            .DB -16, -40                
            .DW $188 * 2                
            .DB $80 + 0, %0011_0001
            
            .DB -16, 24
            .DW $191 * 2 
            .DB $80 + 0, %0000_0000
            
            .DB 16, -8
            .DW $192 * 2 
            .DB $80 + 0, %0000_0000
            
META_GAL2:  .DB 2
            .DB -16, -40                
            .DW $180 * 2                        
            .DB $80 + 1, %0011_1001
                       
            .DB 0, 24
            .DW $190 * 2 
            .DB $80 + 1, %0000_1000
            
META_GAL2b: .DB 3
            .DB -16, -40                
            .DW $188 * 2                 
            .DB $80 + 1, %0011_1001
            
            .DB 0, 24
            .DW $191 * 2 
            .DB $80 + 1, %0000_1000
            
            .DB -32, -8
            .DW $192 * 2 
            .DB $80 + 1, %0000_1000       