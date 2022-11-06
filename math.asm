;Math.asm

VECTOR_MAXLEN   =   8

A_X30 = VECTOR_MAXLEN * 0
A_X45 = VECTOR_MAXLEN * 1
A_X60 = VECTOR_MAXLEN * 2
A_X330 = VECTOR_MAXLEN * 3
A_X315 = VECTOR_MAXLEN * 4
A_X300 = VECTOR_MAXLEN * 5

A_Y30 = VECTOR_MAXLEN * 2
A_Y45 = VECTOR_MAXLEN * 1
A_Y60 = VECTOR_MAXLEN * 0
A_Y330 = VECTOR_MAXLEN * 5
A_Y315 = VECTOR_MAXLEN * 4
A_Y300 = VECTOR_MAXLEN * 3

;This table shows the amount of pixels
;that you should travel in the x/y directions
;in order to move with a certain speed (1-8)
;in 30, 45 or 60 degrees.
Vector_Angle_Table:
	.DB 0, 1, 2, 3, 4, 5, 6, 6 ;30 degree X / 60 degree Y
	.DB 0, 1, 2, 2, 3, 4, 4, 5 ;45 degree X
	.DB 0, 1, 1, 2, 2, 3, 3, 4 ;60 degree X / 30 degree Y
    
    .DB $ff, $fe, $fd, $fc, $fb, $fa, $f9, $f9 ;-30 degree X / -60 degree Y
	.DB $ff, $fe, $fd, $fd, $fc, $fb, $fb, $fa ;-45 degree X
	.DB $ff, $fe, $fe, $fd, $fd, $fc, $fc, $fb ;-60 degree X / -30 degree Y
	
;base 256 fractions to represent the angle as floating point
Vector_Fraction_Table:
    .DB 223, 186, 153, 119, 84, 50, 23, 246 ;30 deg X
	.DB 181, 106, 31, 212, 137, 62, 243, 168 ;45 deg X
	.DB 128, 0, 128, 0, 128, 0, 128, 0 ;60 deg X
    
    .DB $21, $46, $67, $89, $AC, $CE, $E9, $0A ;-30 deg X
	.DB $4B, $96, $E1, $2C, $77, $C2, $0D, $58 ;-45 deg X
	.DB $80, 0, $80, 0, $80, 0, $80, 0 ;-60 deg X