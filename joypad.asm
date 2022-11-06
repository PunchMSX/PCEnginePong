; ***************************************************************************
; ***************************************************************************
;
; joypad.asm
;
; Read 2-button & 6-button joypads & PCE mouse, with or without a MultiTap.
;
; Copyright John Brandwood 2019-2022.
;
; Distributed under the Boost Software License, Version 1.0.
; (See accompanying file LICENSE_1_0.txt or copy at
;  http://www.boost.org/LICENSE_1_0.txt)
;
; ***************************************************************************
; ***************************************************************************
;
; Unlike Lemmings, this code does not interfere with a Memory Base 128! ;-)
;
; ***************************************************************************
; ***************************************************************************
;
; With SUPPORT_MOUSE ..... 2602 cycles to read 5 ports with 5 mice
;
; With HuC library code .. 2442 cycles to read 5 ports with 5 pads (2-button)
; With HuC library code .. 2442 cycles to read 5 ports with 5 pads (6-button)
;
; With SUPPORT_MOUSE ....  2016 cycles to read 5 ports with 5 pads (2-button)
; With SUPPORT_MOUSE ..... 1976 cycles to read 5 ports with 5 pads (6-button)
;
; With SUPPORT_MOUSE ....  1618 cycles to read 3 ports with 3 mice
; With SUPPORT_MOUSE ..... 1462 cycles to read 3 ports with 2 mice
; With SUPPORT_MOUSE ..... 1306 cycles to read 3 ports with 1 mouse
;
; With SUPPORT_6BUTTON ... 1235 cycles to read 5 ports with 5 pads (2-button)
; With SUPPORT_6BUTTON ... 1215 cycles to read 5 ports with 5 pads (6-button)
;
; With SUPPORT_MOUSE ..... 1126 cycles to read 2 ports with 2 mice
; With SUPPORT_MOUSE ...... 970 cycles to read 2 ports with 1 mouse
;
; Only SUPPORT_2BUTTON .... 971 cycles to read 5 ports with 5 pads (2-button)
; Only SUPPORT_2BUTTON .... 861 cycles to read 5 ports with 5 pads (6-button)
;
; With SUPPORT_MOUSE ...... 634 cycles to read 1 port  with 1 mouse
;
; ***************************************************************************
; ***************************************************************************

		;.nolist

;
; Select which version of the joystick library code to include, only one of
; these can be set to '1' ...
;
; SUPPORT_2BUTTON : Only returns buttons I and II.
; SUPPORT_6BUTTON : Read buttons III-VI, but ignore a mouse.
; SUPPORT_MOUSE	  : Read mouse, but ignore buttons III-VI.
;
; It doesn't make sense to design a game the relies on both the 6-button and
; the mouse, so the joystick library is optimized for one or the other.
;
; Note that both those devices are always detected and no conflicts occur,
; this just controls reading either buttons III-VI or the Mouse Y-movement.
;
; There is hidden support for setting both SUPPORT_6BUTTON and SUPPORT_MOUSE
; which has little use in games, but can be useful for hardware-test code.
;

IO_PORT = $1000
const_FFFF:    dw    $FFFF            ; Useful constant for TAI.
const_0000:    dw    $0000            ; Useful constant for TAI.

bit_mask:    db    $01,$02,$04,$08,$10,$20,$40,$80

	.ifndef SUPPORT_2BUTTON
	.ifndef	SUPPORT_6BUTTON
	.ifndef	SUPPORT_MOUSE
SUPPORT_2BUTTON	=	0	; (0 or 1)
SUPPORT_6BUTTON	=	0	; (0 or 1)
SUPPORT_MOUSE	=	1	; (0 or 1)
	.endif
	.endif
	.endif

	.ifndef SUPPORT_2BUTTON
SUPPORT_2BUTTON	=	0
	.endif

;
; How many joypad/mouse devices should be supported?
;
; This is normally 5, but can be set to 3 (or lower) in order to speed up
; the processing and free up CPU time for other code, which is especially
; useful for mouse games.
;

	.ifndef MAX_PADS
MAX_PADS	=	2
	.endif

;
; Remove Phantom Mice?
;
; If there is no multitap, and one mouse in port 1, then the code will
; detect mice in every port.
;
; Setting this adds a check for this case, which then sets the maximum
; number of ports to 1.
;
; Note that it is actually possible to have mice in every port, but it
; is so unlikely that it is easier to use this setting to take care of
; the far-more-common case of having a single mouse and no multitap.
;

	.ifndef DETECT_PHANTOMS
DETECT_PHANTOMS	=	1
	.endif

; ***************************************************************************
; ***************************************************************************
;
; read_joypads - full mouse support, but 6-button pad III..VI are ignored.
;
; This code distinguishes between a mouse and a 2-button or 6-button joypad,
; so that unsupported devices do not have to be unplugged from the MultiTap.
;
; The code loops four times to get both sets of 8-bit mouse delta values.
;
; N.B. Takes approx 1/3 frame to detect mice the first time it is run.
;
; bit values for joypad 2-button bytes: (MSB = #7; LSB = #0)
; ----------------------------------------------------------
; bit 0 (ie $01) = I
; bit 1 (ie $02) = II
; bit 2 (ie $04) = SELECT
; bit 3 (ie $08) = RUN
; bit 4 (ie $10) = UP
; bit 5 (ie $20) = RIGHT
; bit 6 (ie $40) = DOWN
; bit 7 (ie $80) = LEFT
;

		.code
Read_Joypads:
		lda	#$80			; Acquire port mutex to avoid
		tsb	Port_Mutex		; conflict with a delayed VBL
		bmi	.exit			; or access to an MB128.

		tii	Gamepad,Gamepad_Prev,MAX_PADS	; Save the previous values.

		; Detect attached mice the first time this routine is called.

		lda	Mouse_PortMap		; Has mouse detection happened?
		bpl	.detect_mice

		; See what has just been pressed, and check for soft-reset.

.calc_pressed:	jsr	.read_devices		; Read all devices normally.

		ldx	#MAX_PADS - 1

.pressed_loop:	lda	Gamepad, x		; Calc which buttons have just
		tay                             ; been pressed (2-button).
		eor	Gamepad_Prev, x
		and	Gamepad, x
		sta	Gamepad_Trig, x

		cmp	#$04			; Detect the soft-reset combo,
		bne	.not_reset		; hold RUN then press SELECT.
		cpy	#$0C
		bne	.not_reset
		lda	bit_mask, x
		bit	Gamepad_Toggle
		bne	.soft_reset

.not_reset:	dex				; Check the next pad from the
		bpl	.pressed_loop		; multitap.

		stz	Port_Mutex		; Release port mutex.

	.if	(* >= $4000)			; This is a ".proc" if it is
.exit:		rts                          ; not running in RAM.
	.else
.exit:		rts				; All done, phew!
	.endif

.soft_reset:	sei				; Disable interrupts.
		stz	Port_Mutex		; Release port mutex.
		jmp	RESET		; Jump to the soft-reset hook.

		;
		; Detect attached mice the first time this routine is called.
		;

.detect_mice:	lda	#MAX_PADS		; Reset number of pads to read.
		sta	Num_Ports

		lda	#%00011111		; Try reading everything as a
		sta	Mouse_PortMap		; mouse.

		ldy	#15			; Initialize repeat count.
		lda	#$80			; Initialize mouse detection.
.detect_loop:	phy
		pha
		bsr	.read_devices		; Read all devices as if mice.
		pla
		clx
.detect_port:	ldy	Mouse_Y, x		; A movement of zero means
		bne	.detect_next		; this port is a mouse.
		ora	bit_mask, x
.detect_next:	inx				; Get the next pad from the
		cpx	#MAX_PADS		; multitap.
		bne	.detect_port
		ply				; Repeat the detection test.
		dey
		bne	.detect_loop

	.if	DETECT_PHANTOMS
		cmp	#(1 << MAX_PADS) + 127	; If we find a mouse in every
		bne	.detect_done		; port, then assume mirrored!
		lda	#1			; Report a single mouse in a
		sta	Num_Ports		; single port.
		lda	#$81
	.endif

.detect_done:	sta	Mouse_PortMap		; Report mouse detection.
		bra	.calc_pressed

		;
		; Read all of the devices attached to the MultiTap.
		;

.read_devices:	ldx	#6			; Repeat this loop 4 times.

.read_multitap:	lda	#$01			; CLR lo, SEL hi for d-pad.
		sta	IO_PORT
		lda	#$03			; CLR hi, SEL hi, reset tap.
		sta	IO_PORT
		cly				; Start at port 1.

.read_port:	lda	#$01			; CLR lo, SEL hi for d-pad.
		sta	IO_PORT			; Wait 1.25us (9 cycles).

		lda	bit_mask, y		; Is there a mouse attached?
		and	Mouse_PortMap
		bne	.read_mouse

.read_pad:	lda	IO_PORT			; Read direction-pad bits.
		stz	IO_PORT			; CLR lo, SEL lo for buttons.
		asl	a			; Wait 1.25us (9 cycles).
		asl	a
		asl	a
		asl	a
		beq	.next_port		; 6-btn pad if UDLR all held.

.read_2button:	sta	Gamepad, y		; Get buttons of 2-btn pad.
		lda	IO_PORT
		and	#$0F
		ora	Gamepad, y
		eor	#$FF
		sta	Gamepad, y

.next_port:	iny				; Get the next pad from the
		cpy	Num_Ports		; multitap.
		bcc	.read_port

		dex				; Do the next complete pass.
		dex
		bpl	.read_multitap		; Have we finished 4 passes?
		rts				; Now that everything is read.

.read_mouse:	jmp	[.mouse_vectors, x]	; Which mouse info is next?

		;
		; Mouse processing, split into four passes.
		;

.mouse_x_hi:	lda	#28			; 189 cycle delay after CLR lo
.wait_loop:	dec	a			; on port to allow the mouse
		bne	.wait_loop		; to buffer and reset counters.

		lda	IO_PORT			; Read direction-pad bits.
		stz	IO_PORT			; CLR lo, SEL lo for buttons.
		asl	a			; Wait 1.25us (9 cycles).
		asl	a
		asl	a
		asl	a
		sta	Mouse_X, y		; Save port's X-hi nibble.

		lda	IO_PORT			; Get mouse buttons.
		and	#$0F
		eor	#$0F
		sta	Gamepad, y
		bra	.next_port

.mouse_x_lo:	lda	IO_PORT			; Read direction-pad bits.
		stz	IO_PORT			; CLR lo, SEL lo for buttons.
		and	#$0F			; Wait 1.25us (9 cycles).
		ora	Mouse_X, y		; Add port's X-hi nibble.
		eor	#$FF			; Negate so LEFT is -ve.
		inc	a
		sta	Mouse_X, y
		bra	.next_port

.mouse_y_hi:	lda	IO_PORT			; Read direction-pad bits.
		stz	IO_PORT			; CLR lo, SEL lo for buttons.
		asl	a			; Wait 1.25us (9 cycles).
		asl	a
		asl	a
		asl	a
		sta	Mouse_Y, y		; Save port's Y-hi nibble.
		bra	.next_port

.mouse_y_lo:	lda	IO_PORT			; Read direction-pad bits.
		stz	IO_PORT			; CLR lo, SEL lo for buttons.
		and	#$0F			; Wait 1.25us (9 cycles).
		ora	Mouse_Y, y		; Add port's Y-hi nibble.
		eor	#$FF			; Negate so UP is -ve.
		inc	a
		sta	Mouse_Y, y
		bra	.next_port

.mouse_vectors: dw	.mouse_y_lo		; Pass 4
		dw	.mouse_y_hi		; Pass 3
		dw	.mouse_x_lo		; Pass 2
		dw	.mouse_x_hi		; Pass 1


	.bss				; Put the variables in RAM.
Port_Mutex:	ds	1			; NZ when controller port busy.
Num_Ports:	ds	1			; Set to 1 if no multitap.
Mouse_PortMap:	ds	1			; Which ports are mice?
Mouse_X:	ds	MAX_PADS
Mouse_Y:	ds	MAX_PADS

	.code
