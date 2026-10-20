	.text
	.file	"test_legalize.ll"
	.globl	add_i8                          # -- Begin function add_i8
	.p2align	4, 0x90
	.type	add_i8,@function
add_i8:                                 # @add_i8
	.cfi_startproc
# %bb.0:
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %eax
                                        # kill: def $al killed $al killed $eax
	retq
.Lfunc_end0:
	.size	add_i8, .Lfunc_end0-add_i8
	.cfi_endproc
                                        # -- End function
	.globl	add_i16                         # -- Begin function add_i16
	.p2align	4, 0x90
	.type	add_i16,@function
add_i16:                                # @add_i16
	.cfi_startproc
# %bb.0:
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %eax
                                        # kill: def $ax killed $ax killed $eax
	retq
.Lfunc_end1:
	.size	add_i16, .Lfunc_end1-add_i16
	.cfi_endproc
                                        # -- End function
	.globl	add_i64                         # -- Begin function add_i64
	.p2align	4, 0x90
	.type	add_i64,@function
add_i64:                                # @add_i64
	.cfi_startproc
# %bb.0:
	leaq	(%rdi,%rsi), %rax
	retq
.Lfunc_end2:
	.size	add_i64, .Lfunc_end2-add_i64
	.cfi_endproc
                                        # -- End function
	.globl	add_vec3                        # -- Begin function add_vec3
	.p2align	4, 0x90
	.type	add_vec3,@function
add_vec3:                               # @add_vec3
	.cfi_startproc
# %bb.0:
	movzbl	%cl, %eax
	movzbl	%r8b, %ecx
	shll	$8, %ecx
	orl	%eax, %ecx
	movzbl	%r9b, %eax
	shll	$16, %eax
	orl	%ecx, %eax
	movd	%eax, %xmm0
	movzbl	%dil, %eax
	movzbl	%sil, %ecx
	shll	$8, %ecx
	orl	%eax, %ecx
	movzbl	%dl, %eax
	shll	$16, %eax
	orl	%ecx, %eax
	movd	%eax, %xmm1
	paddb	%xmm0, %xmm1
	movd	%xmm1, %eax
	movl	%eax, %ecx
	movl	%eax, %edx
	shrl	$8, %edx
	shrl	$16, %ecx
                                        # kill: def $al killed $al killed $eax
                                        # kill: def $dl killed $dl killed $edx
                                        # kill: def $cl killed $cl killed $ecx
	retq
.Lfunc_end3:
	.size	add_vec3, .Lfunc_end3-add_vec3
	.cfi_endproc
                                        # -- End function
	.globl	add_vec4                        # -- Begin function add_vec4
	.p2align	4, 0x90
	.type	add_vec4,@function
add_vec4:                               # @add_vec4
	.cfi_startproc
# %bb.0:
	paddw	%xmm1, %xmm0
	retq
.Lfunc_end4:
	.size	add_vec4, .Lfunc_end4-add_vec4
	.cfi_endproc
                                        # -- End function
	.globl	add_float                       # -- Begin function add_float
	.p2align	4, 0x90
	.type	add_float,@function
add_float:                              # @add_float
	.cfi_startproc
# %bb.0:
	addss	%xmm1, %xmm0
	retq
.Lfunc_end5:
	.size	add_float, .Lfunc_end5-add_float
	.cfi_endproc
                                        # -- End function
	.globl	add_double                      # -- Begin function add_double
	.p2align	4, 0x90
	.type	add_double,@function
add_double:                             # @add_double
	.cfi_startproc
# %bb.0:
	addsd	%xmm1, %xmm0
	retq
.Lfunc_end6:
	.size	add_double, .Lfunc_end6-add_double
	.cfi_endproc
                                        # -- End function
	.globl	mul_i32                         # -- Begin function mul_i32
	.p2align	4, 0x90
	.type	mul_i32,@function
mul_i32:                                # @mul_i32
	.cfi_startproc
# %bb.0:
	movl	%edi, %eax
	imull	%esi, %eax
	retq
.Lfunc_end7:
	.size	mul_i32, .Lfunc_end7-mul_i32
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
