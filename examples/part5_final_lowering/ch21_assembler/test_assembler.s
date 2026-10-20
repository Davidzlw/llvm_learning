	.text
	.file	"test_assembler.ll"
	.globl	simple_add                      # -- Begin function simple_add
	.p2align	4, 0x90
	.type	simple_add,@function
simple_add:                             # @simple_add
	.cfi_startproc
# %bb.0:
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %eax
	retq
.Lfunc_end0:
	.size	simple_add, .Lfunc_end0-simple_add
	.cfi_endproc
                                        # -- End function
	.globl	with_call                       # -- Begin function with_call
	.p2align	4, 0x90
	.type	with_call,@function
with_call:                              # @with_call
	.cfi_startproc
# %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	external_func@PLT
	popq	%rcx
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	with_call, .Lfunc_end1-with_call
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
