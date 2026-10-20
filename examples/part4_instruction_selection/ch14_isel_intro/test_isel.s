	.text
	.file	"test_isel.ll"
	.globl	add                             # -- Begin function add
	.p2align	4, 0x90
	.type	add,@function
add:                                    # @add
	.cfi_startproc
# %bb.0:
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %eax
	retq
.Lfunc_end0:
	.size	add, .Lfunc_end0-add
	.cfi_endproc
                                        # -- End function
	.globl	mul_add                         # -- Begin function mul_add
	.p2align	4, 0x90
	.type	mul_add,@function
mul_add:                                # @mul_add
	.cfi_startproc
# %bb.0:
                                        # kill: def $edx killed $edx def $rdx
                                        # kill: def $edi killed $edi def $rdi
	imull	%esi, %edi
	leal	(%rdi,%rdx), %eax
	retq
.Lfunc_end1:
	.size	mul_add, .Lfunc_end1-mul_add
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
