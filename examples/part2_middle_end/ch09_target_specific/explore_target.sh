#!/bin/bash
# Chapter 9 实践脚本：观察 target-specific 元素
# 用法: bash explore_target.sh

set -e

echo "=============================================="
echo " Chapter 9: Target-Specific Constructs"
echo "=============================================="
echo ""

# --- 1. Target 信息 ---
echo "=== 1. 当前 target 信息 ==="
echo "默认 target:"
llc --version 2>&1 | grep "Default target"
echo ""

echo "x86_64 data layout:"
echo "" | clang -S -emit-llvm -o - -x c - 2>/dev/null | grep "target datalayout"
echo ""

echo "NVPTX data layout:"
head -3 /home/zhanglw/Code/llvm_learning/test-cuda-nvptx64-nvidia-cuda-sm_89.ll 2>/dev/null || echo "(需要 CUDA test 文件)"
echo ""

# --- 2. Function attributes ---
echo "=== 2. Target-specific function attributes ==="
cat > /tmp/test_attrs.c << 'EOF'
int add(int a, int b) { return a + b; }
EOF
clang -S -emit-llvm -O2 /tmp/test_attrs.c -o /tmp/test_attrs.ll 2>/dev/null
grep "target-cpu\|target-features" /tmp/test_attrs.ll | head -2
echo ""

# --- 3. 不同优化级别下的 target 影响 ---
echo "=== 3. 优化级别对 target 信息的影响 ==="
for opt in O0 O1 O2 O3; do
    echo -n "$opt: "
    clang -S -emit-llvm -$opt /tmp/test_attrs.c -o - 2>/dev/null | grep "target-features" | head -1 | sed 's/.*target-features"="\([^"]*\)".*/\1/' | tr ',' '\n' | wc -l
done
echo ""

# --- 4. NVPTX 后端自定义 Pass ---
echo "=== 4. NVPTX 后端注入的自定义 Pass ==="
echo "define void @f() { ret void }" | \
    llc -march=nvptx64 -mcpu=sm_89 -debug-pass=Structure -o /dev/null 2>&1 | \
    grep -o "\-nvptx[a-z\-]*\|\-nvvm[a-z\-]*\|\-generic-to-nvvm\|\-infer-address-spaces" | \
    sort -u | sed 's/^/  /'
echo ""

# --- 5. 不同 target 的注册 Pass 对比 ---
echo "=== 5. 不同 target 的 Pass 流水线差异 ==="
echo "x86_64 自定义 Pass:"
echo "define void @f() { ret void }" | \
    llc -march=x86-64 -debug-pass=Structure -o /dev/null 2>&1 | \
    grep -o "\-x86[a-z\-]*" | sort -u | sed 's/^/  /'
echo ""

echo "AArch64 自定义 Pass:"
echo "define void @f() { ret void }" | \
    llc -march=aarch64 -debug-pass=Structure -o /dev/null 2>&1 | \
    grep -o "\-aarch64[a-z\-]*" | sort -u | sed 's/^/  /'
echo ""

# --- 6. Intrinsic 观察 ---
echo "=== 6. Target-specific intrinsics ==="
cat > /tmp/test_intrinsic.c << 'EOF'
#include <immintrin.h>
__m128i test_add(__m128i a, __m128i b) {
    return _mm_add_epi32(a, b);
}
EOF
clang -S -emit-llvm -O0 /tmp/test_intrinsic.c -o - 2>/dev/null | grep "llvm.x86\|call.*<4 x i32>" | head -3
echo ""

# --- 7. Data layout 解读 ---
echo "=== 7. Data layout 字段解读 ==="
echo "x86_64: e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
echo "  e     = little-endian"
echo "  m:e   = ELF name mangling"
echo "  i64:64 = i64 aligned to 64 bits"
echo "  n8:16:32:64 = native integer widths"
echo "  S128  = stack natural alignment 128 bits"
echo ""
echo "NVPTX:  e-i64:64-i128:128-v16:16-v32:32-n16:32:64"
echo "  e     = little-endian"
echo "  i64:64 = i64 aligned to 64 bits"
echo "  v16:16 = vec16 aligned to 16 bits"
echo "  n16:32:64 = native integer widths"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
