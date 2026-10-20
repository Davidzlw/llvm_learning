	.text
	.file	"test_abi.ll"
	.globl	caller                          # -- Begin function caller
	.p2align	4, 0x90
	.type	caller,@function
caller:                                 # @caller
	.cfi_startproc
# %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	%esi, %edx
	movl	%edi, %esi
	leal	(%rsi,%rdx), %edi
                                        # kill: def $esi killed $esi killed $rsi
                                        # kill: def $edx killed $edx killed $rdx
	callq	external_func@PLT
	popq	%rcx
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end0:
	.size	caller, .Lfunc_end0-caller
	.cfi_endproc
                                        # -- End function
	.globl	callee                          # -- Begin function callee
	.p2align	4, 0x90
	.type	callee,@function
callee:                                 # @callee
	.cfi_startproc
# %bb.0:
                                        # kill: def $ecx killed $ecx def $rcx
                                        # kill: def $edx killed $edx def $rdx
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	addl	%edi, %esi
	leal	(%rdx,%rcx), %eax
	addl	%esi, %eax
	retq
.Lfunc_end1:
	.size	callee, .Lfunc_end1-callee
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
