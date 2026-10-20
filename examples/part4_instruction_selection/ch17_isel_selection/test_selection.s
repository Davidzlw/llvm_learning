	.text
	.file	"test_selection.ll"
	.globl	arithmetic                      # -- Begin function arithmetic
	.p2align	4, 0x90
	.type	arithmetic,@function
arithmetic:                             # @arithmetic
	.cfi_startproc
# %bb.0:
                                        # kill: def $edx killed $edx def $rdx
                                        # kill: def $esi killed $esi def $rsi
	imull	%edi, %esi
	leal	(%rsi,%rdx), %eax
	subl	%edi, %eax
	retq
.Lfunc_end0:
	.size	arithmetic, .Lfunc_end0-arithmetic
	.cfi_endproc
                                        # -- End function
	.globl	load_offset                     # -- Begin function load_offset
	.p2align	4, 0x90
	.type	load_offset,@function
load_offset:                            # @load_offset
	.cfi_startproc
# %bb.0:
	movslq	%esi, %rax
	movl	(%rdi,%rax,4), %eax
	retq
.Lfunc_end1:
	.size	load_offset, .Lfunc_end1-load_offset
	.cfi_endproc
                                        # -- End function
	.globl	select_max                      # -- Begin function select_max
	.p2align	4, 0x90
	.type	select_max,@function
select_max:                             # @select_max
	.cfi_startproc
# %bb.0:
	movl	%esi, %eax
	cmpl	%esi, %edi
	cmovgl	%edi, %eax
	retq
.Lfunc_end2:
	.size	select_max, .Lfunc_end2-select_max
	.cfi_endproc
                                        # -- End function
	.globl	vec_add                         # -- Begin function vec_add
	.p2align	4, 0x90
	.type	vec_add,@function
vec_add:                                # @vec_add
	.cfi_startproc
# %bb.0:
	paddd	%xmm1, %xmm0
	retq
.Lfunc_end3:
	.size	vec_add, .Lfunc_end3-vec_add
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
