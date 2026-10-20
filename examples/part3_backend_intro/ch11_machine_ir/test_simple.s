	.text
	.file	"test_simple.ll"
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
	.globl	compute                         # -- Begin function compute
	.p2align	4, 0x90
	.type	compute,@function
compute:                                # @compute
	.cfi_startproc
# %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$10, %edi
	movl	$20, %esi
	callq	add@PLT
	popq	%rcx
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	compute, .Lfunc_end1-compute
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
