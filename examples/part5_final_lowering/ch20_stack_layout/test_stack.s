	.text
	.file	"test_stack.ll"
	.globl	stack_test                      # -- Begin function stack_test
	.p2align	4, 0x90
	.type	stack_test,@function
stack_test:                             # @stack_test
	.cfi_startproc
# %bb.0:
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	movl	%edi, -4(%rsp)
	movl	%esi, -8(%rsp)
	leal	(%rdi,%rsi), %eax
	retq
.Lfunc_end0:
	.size	stack_test, .Lfunc_end0-stack_test
	.cfi_endproc
                                        # -- End function
	.globl	caller                          # -- Begin function caller
	.p2align	4, 0x90
	.type	caller,@function
caller:                                 # @caller
	.cfi_startproc
# %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$42, %esi
	callq	external@PLT
	popq	%rcx
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	caller, .Lfunc_end1-caller
	.cfi_endproc
                                        # -- End function
	.globl	large_stack                     # -- Begin function large_stack
	.p2align	4, 0x90
	.type	large_stack,@function
large_stack:                            # @large_stack
	.cfi_startproc
# %bb.0:
	subq	$272, %rsp                      # imm = 0x110
	.cfi_def_cfa_offset 280
	movl	$999, -128(%rsp)                # imm = 0x3E7
	movl	$999, %eax                      # imm = 0x3E7
	addq	$272, %rsp                      # imm = 0x110
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end2:
	.size	large_stack, .Lfunc_end2-large_stack
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
