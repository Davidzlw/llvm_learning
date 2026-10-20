	.text
	.file	"test_regalloc.ll"
	.globl	high_pressure                   # -- Begin function high_pressure
	.p2align	4, 0x90
	.type	high_pressure,@function
high_pressure:                          # @high_pressure
	.cfi_startproc
# %bb.0:
                                        # kill: def $ecx killed $ecx def $rcx
                                        # kill: def $edx killed $edx def $rdx
                                        # kill: def $esi killed $esi def $rsi
                                        # kill: def $edi killed $edi def $rdi
	leal	(%rdi,%rsi), %r9d
	leal	(%rcx,%rdx), %eax
	imull	%r9d, %eax
	addl	%r8d, %eax
	subl	%edi, %eax
	imull	%esi, %eax
	addl	%edx, %eax
	retq
.Lfunc_end0:
	.size	high_pressure, .Lfunc_end0-high_pressure
	.cfi_endproc
                                        # -- End function
	.globl	long_live                       # -- Begin function long_live
	.p2align	4, 0x90
	.type	long_live,@function
long_live:                              # @long_live
	.cfi_startproc
# %bb.0:
                                        # kill: def $edi killed $edi def $rdi
	leal	55(%rdi), %eax
	retq
.Lfunc_end1:
	.size	long_live, .Lfunc_end1-long_live
	.cfi_endproc
                                        # -- End function
	.globl	phi_merge                       # -- Begin function phi_merge
	.p2align	4, 0x90
	.type	phi_merge,@function
phi_merge:                              # @phi_merge
	.cfi_startproc
# %bb.0:
	testb	$1, %dl
	je	.LBB2_2
# %bb.1:                                # %then
	movl	%edi, %eax
	addl	$10, %eax
	retq
.LBB2_2:                                # %else
	addl	$20, %esi
	movl	%esi, %eax
	retq
.Lfunc_end2:
	.size	phi_merge, .Lfunc_end2-phi_merge
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
