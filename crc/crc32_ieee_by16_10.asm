;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Copyright(c) 2011-2020 Intel Corporation All rights reserved.
;
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions
;  are met:
;    * Redistributions of source code must retain the above copyright
;      notice, this list of conditions and the following disclaimer.
;    * Redistributions in binary form must reproduce the above copyright
;      notice, this list of conditions and the following disclaimer in
;      the documentation and/or other materials provided with the
;      distribution.
;    * Neither the name of Intel Corporation nor the names of its
;      contributors may be used to endorse or promote products derived
;      from this software without specific prior written permission.
;
;  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;       Function API:
;       UINT32 crc32_gzip_refl_by16_10(
;               UINT32 init_crc, //initial CRC value, 32 bits
;               const unsigned char *buf, //buffer pointer to calculate CRC on
;               UINT64 len //buffer length in bytes (64-bit data)
;       );
;
;       Authors:
;               Erdinc Ozturk
;               Vinodh Gopal
;               James Guilford
;
;       Reference paper titled "Fast CRC Computation for Generic Polynomials Using PCLMULQDQ Instruction"
;       URL: http://www.intel.com/content/dam/www/public/us/en/documents/white-papers/fast-crc-computation-generic-polynomials-pclmulqdq-paper.pdf
;
;

%include "reg_sizes.asm"

%ifndef FUNCTION_NAME
%define FUNCTION_NAME crc32_ieee_by16_10
%endif

[bits 64]
default rel

section .text


%ifidn __OUTPUT_FORMAT__, win64
	%xdefine	arg1 rcx
	%xdefine	arg2 rdx
	%xdefine	arg3 r8

	%xdefine	arg1_low32 ecx
%else
	%xdefine	arg1 rdi
	%xdefine	arg2 rsi
	%xdefine	arg3 rdx

	%xdefine	arg1_low32 edi
%endif

align 16
mk_global FUNCTION_NAME, function
FUNCTION_NAME:
	endbranch

	not		arg1_low32

%ifidn __OUTPUT_FORMAT__, win64
	sub		rsp, (16*10 + 8)

	; push the xmm registers into the stack to maintain
	vmovdqa		[rsp + 16*0], xmm6
	vmovdqa		[rsp + 16*1], xmm7
	vmovdqa		[rsp + 16*2], xmm8
	vmovdqa		[rsp + 16*3], xmm9
	vmovdqa		[rsp + 16*4], xmm10
	vmovdqa		[rsp + 16*5], xmm11
	vmovdqa		[rsp + 16*6], xmm12
	vmovdqa		[rsp + 16*7], xmm13
	vmovdqa		[rsp + 16*8], xmm14
	vmovdqa		[rsp + 16*9], xmm15
%endif

	vbroadcasti32x4 zmm18, [SHUF_MASK]
	cmp		arg3, 256
	jl		.less_than_256

	; load the initial crc value
	vmovd		xmm10, arg1_low32      ; initial crc

	; crc value does not need to be byte-reflected, but it needs to be moved to the high part of the register.
	; because data will be byte-reflected and will align with initial crc at correct place.
	vpslldq		xmm10, 12

	; receive the initial 64B data, xor the initial crc value
	vmovdqu8	zmm0, [arg2+16*0]
	vmovdqu8	zmm4, [arg2+16*4]
	vpshufb		zmm0, zmm0, zmm18
	vpshufb		zmm4, zmm4, zmm18
	vpxorq		zmm0, zmm10
	vbroadcasti32x4	zmm10, [rk3]	;xmm10 has rk3 and rk4
					;imm value of pclmulqdq instruction will determine which constant to use

	sub		arg3, 256
	cmp		arg3, 256
	jl		.fold_128_B_loop

	vmovdqu8	zmm7, [arg2+16*8]
	vmovdqu8	zmm8, [arg2+16*12]
	vpshufb		zmm7, zmm7, zmm18
	vpshufb		zmm8, zmm8, zmm18
	vbroadcasti32x4 zmm16, [rk_1]	;zmm16 has rk-1 and rk-2
	sub		arg3, 256

align 16
.fold_256_B_loop:
	add		arg2, 256
	vmovdqu8	zmm3, [arg2+16*0]
	vpshufb		zmm3, zmm3, zmm18
	vpclmulqdq	zmm1, zmm0, zmm16, 0x00
	vpclmulqdq	zmm0, zmm0, zmm16, 0x11
	vpternlogq	zmm0, zmm1, zmm3, 0x96

	vmovdqu8	zmm9, [arg2+16*4]
	vpshufb		zmm9, zmm9, zmm18
	vpclmulqdq	zmm5, zmm4, zmm16, 0x00
	vpclmulqdq	zmm4, zmm4, zmm16, 0x11
	vpternlogq	zmm4, zmm5, zmm9, 0x96

	vmovdqu8	zmm11, [arg2+16*8]
	vpshufb		zmm11, zmm11, zmm18
	vpclmulqdq	zmm12, zmm7, zmm16, 0x00
	vpclmulqdq	zmm7, zmm7, zmm16, 0x11
	vpternlogq	zmm7, zmm12, zmm11, 0x96

	vmovdqu8	zmm17, [arg2+16*12]
	vpshufb		zmm17, zmm17, zmm18
	vpclmulqdq	zmm14, zmm8, zmm16, 0x00
	vpclmulqdq	zmm8, zmm8, zmm16, 0x11
	vpternlogq	zmm8, zmm14, zmm17, 0x96

	sub		arg3, 256
	jge     	.fold_256_B_loop

	;; Fold 256 into 128
	add		arg2, 256
	vpclmulqdq	zmm1, zmm0, zmm10, 0x00
	vpclmulqdq	zmm2, zmm0, zmm10, 0x11
	vpternlogq	zmm7, zmm1, zmm2, 0x96	; xor ABC

	vpclmulqdq	zmm5, zmm4, zmm10, 0x00
	vpclmulqdq	zmm6, zmm4, zmm10, 0x11
	vpternlogq	zmm8, zmm5, zmm6, 0x96	; xor ABC

	vmovdqa32	zmm0, zmm7
	vmovdqa32	zmm4, zmm8

	add		arg3, 128
        jmp             .less_than_128_B

	; at this section of the code, there is 128*x+y (0<=y<128) bytes of buffer. The fold_128_B_loop
	; loop will fold 128B at a time until we have 128+y Bytes of buffer

	; fold 128B at a time. This section of the code folds 8 xmm registers in parallel
align 16
.fold_128_B_loop:
	add		arg2, 128
	vmovdqu8	zmm8, [arg2+16*0]
	vpshufb		zmm8, zmm8, zmm18
	vpclmulqdq	zmm2, zmm0, zmm10, 0x00
	vpclmulqdq	zmm0, zmm0, zmm10, 0x11
	vpternlogq	zmm0, zmm2, zmm8, 0x96

	vmovdqu8	zmm9, [arg2+16*4]
	vpshufb		zmm9, zmm9, zmm18
	vpclmulqdq	zmm5, zmm4, zmm10, 0x00
	vpclmulqdq	zmm4, zmm4, zmm10, 0x11
	vpternlogq	zmm4, zmm5, zmm9, 0x96

	sub		arg3, 128
	jge		.fold_128_B_loop
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	add		arg2, 128
align 16
.less_than_128_B:
        ;; At this point, the buffer pointer is pointing at the last
        ;; y bytes of the buffer, where 0 <= y < 128.
        ;; The 128 bytes of folded data is in 2 of the zmm registers:
        ;;     zmm0 and zmm4

        cmp             arg3, -64
        jl              .fold_128_B_register

        vbroadcasti32x4 zmm10, [rk15]
        ;; If there are still 64 bytes left, folds from 128 bytes to 64 bytes
        ;; and handles the next 64 bytes
        vpclmulqdq      zmm2, zmm0, zmm10, 0x00
        vpclmulqdq      zmm0, zmm0, zmm10, 0x11
        vpternlogq      zmm0, zmm2, zmm4, 0x96
        add             arg3, 128

        jmp             .fold_64B_loop

align 16
.fold_128_B_register:
	; fold the 8 128b parts into 1 xmm register with different constants
	vmovdqu8	zmm16, [rk9]		; multiply by rk9-rk16
	vmovdqu8	zmm11, [rk17]		; multiply by rk17-rk20, rk1,rk2, 0,0
	vpclmulqdq	zmm1, zmm0, zmm16, 0x00
	vpclmulqdq	zmm2, zmm0, zmm16, 0x11
	vextracti64x2	xmm7, zmm4, 3		; save last that has no multiplicand

	vpclmulqdq	zmm5, zmm4, zmm11, 0x00
	vpclmulqdq	zmm6, zmm4, zmm11, 0x11
	vmovdqa		xmm10, [rk1]		; Needed later in reduction loop
	vpternlogq	zmm1, zmm2, zmm5, 0x96	; xor ABC
	vpternlogq	zmm1, zmm6, zmm7, 0x96	; xor ABC

	vshufi64x2      zmm8, zmm1, zmm1, 0x4e ; Swap 1,0,3,2 - 01 00 11 10
	vpxorq          ymm8, ymm8, ymm1
	vextracti64x2   xmm5, ymm8, 1
	vpxorq          xmm7, xmm5, xmm8

	; instead of 128, we add 128-16 to the loop counter to save 1 instruction from the loop
	; instead of a cmp instruction, we use the negative flag with the jl instruction
	add		arg3, 128-16
	jl		.final_reduction_for_128

	; now we have 16+y bytes left to reduce. 16 Bytes is in register xmm7 and the rest is in memory
	; we can fold 16 bytes at a time if y>=16
	; continue folding 16B at a time

align 16
.16B_reduction_loop:
	vpclmulqdq	xmm8, xmm7, xmm10, 0x11
	vpclmulqdq	xmm7, xmm7, xmm10, 0x00
	vpxor		xmm7, xmm8
	vmovdqu		xmm0, [arg2]
	vpshufb		xmm0, xmm0, xmm18
	vpxor		xmm7, xmm0
	add		arg2, 16
	sub		arg3, 16
	; instead of a cmp instruction, we utilize the flags with the jge instruction
	; equivalent of: cmp arg3, 16-16
	; check if there is any more 16B in the buffer to be able to fold
	jge		.16B_reduction_loop

	;now we have 16+z bytes left to reduce, where 0<= z < 16.
	;first, we reduce the data in the xmm7 register


align 16
.final_reduction_for_128:
	add		arg3, 16
	je		.128_done

	; here we are getting data that is less than 16 bytes.
	; since we know that there was data before the pointer, we can offset
	; the input pointer before the actual point, to receive exactly 16 bytes.
	; after that the registers need to be adjusted.
align 16
.get_last_two_xmms:

	vmovdqa		xmm2, xmm7
	vmovdqu		xmm1, [arg2 - 16 + arg3]
	vpshufb		xmm1, xmm18

	; get rid of the extra data that was loaded before
	; load the shift constant
	lea		rax, [rel pshufb_shf_table + 16]
	sub		rax, arg3
	vmovdqu		xmm0, [rax]

	vpshufb		xmm2, xmm0
	vpxor		xmm0, [mask1]
	vpshufb		xmm7, xmm0
	vpblendvb	xmm1, xmm1, xmm2, xmm0

	vpclmulqdq	xmm8, xmm7, xmm10, 0x11
	vpclmulqdq	xmm7, xmm7, xmm10, 0x00
        vpternlogq      xmm7, xmm8, xmm1, 0x96

align 16
.128_done:
	; compute crc of a 128-bit value
	vmovdqa		xmm10, [rk5]
	vmovdqa		xmm0, xmm7

	;64b fold
	vpclmulqdq	xmm7, xmm10, 0x01	; H*L
	vpslldq		xmm0, 8
	vpxor		xmm7, xmm0

	;32b fold
	vpand		xmm0, xmm7, [mask2]
	vpsrldq		xmm7, 12
	vpclmulqdq	xmm7, xmm10, 0x10
	vpxor		xmm7, xmm0

	;barrett reduction
align 16
.barrett:
	vmovdqa		xmm10, [rk7]	; rk7 and rk8 in xmm10
	vmovdqa		xmm0, xmm7
	vpclmulqdq	xmm7, xmm10, 0x01
	vpslldq		xmm7, 4
	vpclmulqdq	xmm7, xmm10, 0x11

	vpslldq		xmm7, 4
	vpxor		xmm7, xmm0
	vpextrd		eax, xmm7, 1

align 16
.cleanup:
	not		eax


%ifidn __OUTPUT_FORMAT__, win64
	vmovdqa		xmm6, [rsp + 16*0]
	vmovdqa		xmm7, [rsp + 16*1]
	vmovdqa		xmm8, [rsp + 16*2]
	vmovdqa		xmm9, [rsp + 16*3]
	vmovdqa		xmm10, [rsp + 16*4]
	vmovdqa		xmm11, [rsp + 16*5]
	vmovdqa		xmm12, [rsp + 16*6]
	vmovdqa		xmm13, [rsp + 16*7]
	vmovdqa		xmm14, [rsp + 16*8]
	vmovdqa		xmm15, [rsp + 16*9]
	add		rsp, (16*10 + 8)
%endif
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 16
.less_than_256:

	; check if there is enough buffer to be able to fold 16B at a time
	cmp	arg3, 32
	jl	.less_than_32

	vmovd	xmm1, arg1_low32	; get the initial crc value
        vpslldq         xmm1, 12

	cmp	arg3, 64
	jl	.less_than_64

        ;; receive the initial 64B data, xor the initial crc value
        vmovdqu8        zmm0, [arg2]
        vpshufb         zmm0, zmm18
        vpxorq          zmm0, zmm1
        add             arg2, 64
        sub             arg3, 64

        cmp             arg3, 64
        jb              .reduce_64B

        vbroadcasti32x4 zmm10, [rk15]

align 16
.fold_64B_loop:
        vmovdqu8        zmm4, [arg2]
        vpshufb         zmm4, zmm18
        vpclmulqdq      zmm2, zmm0, zmm10, 0x11
        vpclmulqdq      zmm0, zmm0, zmm10, 0x00
        vpternlogq      zmm0, zmm2, zmm4, 0x96

        add             arg2, 64
        sub             arg3, 64

        cmp             arg3, 64
        jge             .fold_64B_loop

align 16
.reduce_64B:
        ; Reduce from 64 bytes to 16 bytes
	vmovdqu8	zmm11, [rk17]
	vpclmulqdq	zmm1, zmm0, zmm11, 0x11
	vpclmulqdq	zmm2, zmm0, zmm11, 0x00
	vextracti64x2	xmm7, zmm0, 3		; save last that has no multiplicand
        vpternlogq      zmm1, zmm2, zmm7, 0x96

	vmovdqa		xmm10, [rk_1b] ; Needed later in reduction loop

	vshufi64x2      zmm8, zmm1, zmm1, 0x4e ; Swap 1,0,3,2 - 01 00 11 10
	vpxorq          ymm8, ymm8, ymm1
	vextracti64x2   xmm5, ymm8, 1
	vpxorq          xmm7, xmm5, xmm8

        sub             arg3, 16
        jns             .16B_reduction_loop ; At least 16 bytes of data to digest
        jmp             .final_reduction_for_128

align 16
.less_than_64:
	;; if there is, load the constants
	vmovdqa	xmm10, [rk_1b]

	vmovdqu	xmm7, [arg2]		; load the plaintext
        vpshufb xmm7, xmm18
	vpxor	xmm7, xmm1              ; xmm1 already has initial crc value

	;; update the buffer pointer
	add	arg2, 16

        ;; update the counter
        ;; - subtract 32 instead of 16 to save one instruction from the loop
	sub	arg3, 32
	jmp	.16B_reduction_loop

align 16
.less_than_32:
	; mov initial crc to the return value. this is necessary for zero-length buffers.
	mov	eax, arg1_low32
	test	arg3, arg3
	je	.cleanup

	vmovd	xmm0, arg1_low32	; get the initial crc value
	vpslldq	xmm0, 12		; align it to its correct place

	cmp	arg3, 16
	je	.exact_16_left
	jl	.less_than_16_left

	vmovdqu	xmm7, [arg2]		; load the plaintext
	vpshufb	xmm7, xmm18
	vpxor	xmm7, xmm0		; xor the initial crc value
	add	arg2, 16
	sub	arg3, 16
	vmovdqa	xmm10, [rk1]		; rk1 and rk2 in xmm10
	jmp	.get_last_two_xmms

align 16
.less_than_16_left:
        xor     r10, r10
        bts     r10, arg3
        dec     r10
        kmovw   k2, r10d
        vmovdqu8 xmm7{k2}{z}, [arg2]
	vpshufb	xmm7, xmm18		; byte-reflect the plaintext

	vpxor	xmm7, xmm0	; xor the initial crc value

	cmp	arg3, 4
	jb	.only_less_than_4

	lea	rax, [rel pshufb_shf_table + 16]
	sub	rax, arg3
	vmovdqu	xmm0, [rax]
	vpxor	xmm0, [mask1]

	vpshufb	xmm7,xmm0
	jmp	.128_done

align 16
.only_less_than_4:
        lea     r11, [rel pshufb_shift_table + 3]
        sub     r11, arg3
        vmovdqu	xmm0, [r11]
        vpshufb	xmm7, xmm0
        jmp	.barrett
align 32
.exact_16_left:
	vmovdqu	xmm7, [arg2]
        vpshufb xmm7, xmm18
	vpxor	xmm7, xmm0      ; xor the initial crc value

	jmp	.128_done

section .data
align 32

%ifndef USE_CONSTS
; precomputed constants
rk_1: dq 0x1851689900000000
rk_2: dq 0xa3dc855100000000
rk1:  dq 0xf200aa6600000000
rk2:  dq 0x17d3315d00000000
rk3:  dq 0x022ffca500000000
rk4:  dq 0x9d9ee22f00000000
rk5:  dq 0xf200aa6600000000
rk6:  dq 0x490d678d00000000
rk7:  dq 0x0000000104d101df
rk8:  dq 0x0000000104c11db7
rk9:  dq 0x6ac7e7d700000000
rk10: dq 0xfcd922af00000000
rk11: dq 0x34e45a6300000000
rk12: dq 0x8762c1f600000000
rk13: dq 0x5395a0ea00000000
rk14: dq 0x54f2d5c700000000
rk15: dq 0xd3504ec700000000
rk16: dq 0x57a8445500000000
rk17: dq 0xc053585d00000000
rk18: dq 0x766f1b7800000000
rk19: dq 0xcd8c54b500000000
rk20: dq 0xab40b71e00000000

rk_1b: dq 0xf200aa6600000000
rk_2b: dq 0x17d3315d00000000
	dq 0x0000000000000000
	dq 0x0000000000000000
%else
INCLUDE_CONSTS
%endif

align 16
pshufb_shift_table:
        ;; use these values to shift data for the pshufb instruction
        db 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
        db 0x0C, 0x0D, 0x0E, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF
        db 0xFF, 0xFF

mask1: dq 0x8080808080808080, 0x8080808080808080
mask2: dq 0xFFFFFFFFFFFFFFFF, 0x00000000FFFFFFFF

SHUF_MASK: dq 0x08090A0B0C0D0E0F, 0x0001020304050607

pshufb_shf_table:
; use these values for shift constants for the pshufb instruction
; different alignments result in values as shown:
;       dq 0x8887868584838281, 0x008f8e8d8c8b8a89 ; shl 15 (16-1) / shr1
;       dq 0x8988878685848382, 0x01008f8e8d8c8b8a ; shl 14 (16-3) / shr2
;       dq 0x8a89888786858483, 0x0201008f8e8d8c8b ; shl 13 (16-4) / shr3
;       dq 0x8b8a898887868584, 0x030201008f8e8d8c ; shl 12 (16-4) / shr4
;       dq 0x8c8b8a8988878685, 0x04030201008f8e8d ; shl 11 (16-5) / shr5
;       dq 0x8d8c8b8a89888786, 0x0504030201008f8e ; shl 10 (16-6) / shr6
;       dq 0x8e8d8c8b8a898887, 0x060504030201008f ; shl 9  (16-7) / shr7
;       dq 0x8f8e8d8c8b8a8988, 0x0706050403020100 ; shl 8  (16-8) / shr8
;       dq 0x008f8e8d8c8b8a89, 0x0807060504030201 ; shl 7  (16-9) / shr9
;       dq 0x01008f8e8d8c8b8a, 0x0908070605040302 ; shl 6  (16-10) / shr10
;       dq 0x0201008f8e8d8c8b, 0x0a09080706050403 ; shl 5  (16-11) / shr11
;       dq 0x030201008f8e8d8c, 0x0b0a090807060504 ; shl 4  (16-12) / shr12
;       dq 0x04030201008f8e8d, 0x0c0b0a0908070605 ; shl 3  (16-13) / shr13
;       dq 0x0504030201008f8e, 0x0d0c0b0a09080706 ; shl 2  (16-14) / shr14
;       dq 0x060504030201008f, 0x0e0d0c0b0a090807 ; shl 1  (16-15) / shr15
dq 0x8786858483828100, 0x8f8e8d8c8b8a8988
dq 0x0706050403020100, 0x000e0d0c0b0a0908
dq 0x8080808080808080, 0x0f0e0d0c0b0a0908
dq 0x8080808080808080, 0x8080808080808080
