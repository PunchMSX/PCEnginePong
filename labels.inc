; --------
; This block defines names for standard
; devices and equipment on the PC-Engine.
; (they should be self-explanatory...)
;

; ----
; VDC (Video Display Controller)

videoport	.equ $0000

video_reg	.equ videoport
video_reg_l	.equ video_reg
video_reg_h	.equ video_reg+1

video_data	.equ videoport+2
video_data_l	.equ video_data
video_data_h	.equ video_data+1


.ifdef _SGX
; ----
; SGX VDC (Video Display Controller)

sgx_videoport		.equ $0010

sgx_video_reg		.equ sgx_videoport
sgx_video_reg_l		.equ sgx_video_reg
sgx_video_reg_h		.equ sgx_video_reg+1

sgx_video_data		.equ sgx_videoport+2
sgx_video_data_l	.equ sgx_video_data
sgx_video_data_h	.equ sgx_video_data+1


; ----
; SGX VPC (Video Priority Controller)

sgx_vpcport	.equ $0008

vpc_ctrl_1	.equ sgx_vpcport
vpc_ctrl_2	.equ sgx_vpcport+1

vpc_window_1	.equ sgx_vpcport+2
vpc_window_1_l	.equ vpc_window_1
vpc_window_1_h	.equ vpc_window_1+1

vpc_window_2	.equ sgx_vpcport+4
vpc_window_2_l	.equ vpc_window_2
vpc_window_2_h	.equ vpc_window_2+1

vpc_vdc_redir	.equ sgx_vpcport+6

.endif ; _SGX

; ----
; VCE (Video Color Encoder)

colorport	.equ $0400
color_ctrl	.equ colorport

color_reg	.equ colorport+2
color_reg_l	.equ color_reg
color_reg_h	.equ color_reg+1

color_data	.equ colorport+4
color_data_l	.equ color_data
color_data_h	.equ color_data+1

.ifdef HUC
_color_reg	.equ colorport+2
_color_data	.equ colorport+4
.endif


; ----
; PSG (Programmable Sound Generator)

psgport		.equ $0800
psg_ch		.equ psgport
psg_mainvol	.equ psgport+1
psg_freqlo	.equ psgport+2
psg_freqhi	.equ psgport+3
psg_ctrl	.equ psgport+4
psg_pan		.equ psgport+5
psg_wavebuf	.equ psgport+6
psg_noise	.equ psgport+7
psg_lfofreq	.equ psgport+8
psg_lfoctrl	.equ psgport+9


; ----
; TIMER

timerport	.equ $0C00
timer_cnt	.equ timerport
timer_ctrl	.equ timerport+1


; ----
; I/O port

joyport		.equ $1000


; ----
; IRQ ports

irqport		.equ $1400
irq_disable	.equ irqport+2
irq_status	.equ irqport+3


; --------
; This block defines names for macro
; argument types (\?x).
;

ARG_NONE	.equ 0
ARG_REG		.equ 1
ARG_IMMED	.equ 2
ARG_ABS		.equ 3
ARG_ABSOLUTE	.equ 3
ARG_INDIRECT	.equ 4
ARG_STRING	.equ 5
ARG_LABEL	.equ 6