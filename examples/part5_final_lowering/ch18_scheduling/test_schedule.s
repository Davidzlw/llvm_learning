	.text
	.file	"test_schedule.ll"
	.globl	chain                           # -- Begin function chain
	.p2align	4, 0x90
	.type	chain,@function
chain:                                  # @chain
	.cfi_startproc
# %bb.0:
                                        # kill: def $edx killed $edx def $rdx
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %ecx
	leal	(%rdx,%rcx), %eax
	addl	%ecx, %eax
	retq
.Lfunc_end0:
	.size	chain, .Lfunc_end0-chain
	.cfi_endproc
                                        # -- End function
	.globl	parallel                        # -- Begin function parallel
	.p2align	4, 0x90
	.type	parallel,@function
parallel:                               # @parallel
	.cfi_startproc
# %bb.0:
                                        # kill: def $ecx killed $ecx def $rcx
                                        # kill: def $edx killed $edx def $rdx
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %r8d
	leal	(%rdx,%rcx), %eax
	imull	%r8d, %eax
	subl	%edx, %edi
	subl	%ecx, %esi
	addl	%esi, %eax
	addl	%edi, %eax
	retq
.Lfunc_end1:
	.size	parallel, .Lfunc_end1-parallel
	.cfi_endproc
                                        # -- End function
	.globl	memory                          # -- Begin function memory
	.p2align	4, 0x90
	.type	memory,@function
memory:                                 # @memory
	.cfi_startproc
# %bb.0:
	movl	(%rdi), %eax
	addl	(%rsi), %eax
	movl	%edx, (%rdi)
	retq
.Lfunc_end2:
	.size	memory, .Lfunc_end2-memory
	.cfi_endproc
                                        # -- End function
	.globl	float_ops                       # -- Begin function float_ops
	.p2align	4, 0x90
	.type	float_ops,@function
float_ops:                              # @float_ops
	.cfi_startproc
# %bb.0:
	mulss	%xmm0, %xmm1
	addss	%xmm2, %xmm1
	divss	%xmm0, %xmm1
	movaps	%xmm1, %xmm0
	retq
.Lfunc_end3:
	.size	float_ops, .Lfunc_end3-float_ops
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
