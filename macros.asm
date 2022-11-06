 .MACRO SETREG ;BAI HADASAN
 .IF (\?1 != 2)
	.fail
 .endif
	LDA \1
	STA <_ar_buf
	ST0 \1
 .endm

 .MACRO VBLANK
    JSR Upload_OAM  ;This has to be done before next vblank or it takes effect 1 frame later
    INC VDC_Busy
 .wait\@:
    LDA VDC_Busy
    BNE .wait\@
    .ENDM
 
 ;Extends a signed 8-bit integer in A to a 16-bit signed integer.
 .macro EXTSIGN
    ORA #%0_1111111 ;Flag N will only be set if # in A is > 127
    BMI .end\@
    LDA #0
 .end\@:	
	.ENDM
    
;Negates number.
 .macro NEG
	EOR #$FF
    CLC
	ADC #1
	.endm

 .MACRO NEG16
 .if (\# != 1)
	.fail
 .endif
	LDA \1
	EOR #$FF
	CLC
	ADC #1
	TAX
	LDA \1 + 1
	EOR #$FF
	ADC #0
	.ENDM
	
 .MACRO NEG16_v2
 .if (\# != 1)
	.fail
 .endif
	LDA \1
	EOR #$FF
	CLC
	ADC #1
	STA \1
	LDA \1 + 1
	EOR #$FF
	ADC #0
	STA \1 + 1
	.ENDM

 .MACRO CMPSIGN16 ;BMI 1 < 2 BPL 1 >= 2
	LDA \1 ; NUM1-NUM2
 .IF (\?2 == 2)
		CMP #LOW(\2)
 .ELSE
		CMP \2
 .ENDIF
	LDA \1 + 1
 .IF (\?2 == 2)
		SBC #HIGH(\2)
 .ELSE
		SBC \2 + 1
 .ENDIF
	BVC .end\@ ; N eor V
	EOR #$80
 .end\@:
	.endm

 .MACRO INC16
 .if (\# > 2)
	.fail
 .endif
 .IF (\# > 1)
    INC \1
    BNE .exit\@
    INC \2
 .ENDIF
 .if (\# < 2)
	INC \1
	BNE .exit\@
	INC \1 + 1
 .endif
 .exit\@:
	.endm 
	
 .macro DEC16
 .if (\# > 1)
	.fail
 .endif
	DEC \1
	LDA \1
	CMP #$FF
	BNE .exit\@
	DEC \1 + 1
 .exit\@:
	.ENDM 

 .MACRO ADC16
    CLC
	ADC \1
	STA \1
	LDA #0
	ADC \1 + 1
	STA \1 + 1
	.ENDM
    
 .MACRO SET_SDLEN
  .IF (\# != 3)
	.fail
 .endif
    LDA #LOW(\1)
	STA <_sl
	LDA #HIGH(\1)
	STA <_sh
	LDA #LOW(\2)
	STA <_dl
	LDA #HIGH(\2)
	STA <_dh
	LDA #LOW(\3)
	STA <_al
	LDA #HIGH(\3)
	STA <_ah
 .end\@:	
	.ENDM
    
 .MACRO SET_SDAB
  .IF (\# != 4)
	.fail
 .endif
    LDA #LOW(\1)
	STA <_sl
	LDA #HIGH(\1)
	STA <_sh
	LDA #LOW(\2)
	STA <_dl
	LDA #HIGH(\2)
	STA <_dh
	LDA #LOW(\3)
	STA <_al
	LDA #HIGH(\3)
	STA <_ah
    LDA #LOW(\4)
	STA <_bl
	LDA #HIGH(\4)
	STA <_bh
 .end\@:	
	.ENDM
	
 .MACRO SET_AB
  .IF (\# != 2)
	.fail
 .endif
	LDA #LOW(\1)
	STA <_al
	LDA #HIGH(\1)
	STA <_ah
    LDA #LOW(\2)
	STA <_bl
	LDA #HIGH(\2)
	STA <_bh
 .end\@:	
	.endm