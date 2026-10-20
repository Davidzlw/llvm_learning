#!/bin/bash
# Chapter 17 实践脚本：观察 Selection Phase
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 17: Selection Phase"
echo "=============================================="
echo ""

cat > test_selection.ll << 'EOF'
define i32 @arithmetic(i32 %a, i32 %b, i32 %c) {
  %mul = mul i32 %a, %b
  %add = add i32 %mul, %c
  %sub = sub i32 %add, %a
  ret i32 %sub
}

define i32 @load_offset(i32* %ptr, i32 %offset) {
  %addr = getelementptr i32, i32* %ptr, i32 %offset
  %val = load i32, i32* %addr
  ret i32 %val
}

define i32 @select_max(i32 %a, i32 %b) {
  %cmp = icmp sgt i32 %a, %b
  %result = select i1 %cmp, i32 %a, i32 %b
  ret i32 %result
}

define <4 x i32> @vec_add(<4 x i32> %a, <4 x i32> %b) {
  % sum = add <4 x i32> %a, %b
  ret <4 x i32> %sum
}
EOF

echo "=== 1. NVPTX 指令选择 ==="
llc -march=nvptx64 -mcpu=sm_89 test_selection.ll -o test_selection.ptx 2>/dev/null
echo "arithmetic (mad 融合):"
grep -A 6 "arithmetic:" test_selection.ptx | head -8
echo ""
echo "select_max (max 指令):"
grep -A 4 "select_max:" test_selection.ptx | head -6
echo ""
echo "vec_add (标量化):"
grep -A 8 "vec_add:" test_selection.ptx | head -10
echo ""

echo "=== 2. x86_64 指令选择 ==="
llc -march=x86-64 test_selection.ll -o test_selection.s 2>/dev/null
echo "arithmetic (imul+lea):"
grep -A 5 "arithmetic:" test_selection.s | head -7
echo ""
echo "load_offset (复杂地址模式):"
grep -A 3 "load_offset:" test_selection.s | head -5
echo ""
echo "select_max (cmov 条件移动):"
grep -A 5 "select_max:" test_selection.s | head -7
echo ""
echo "vec_add (SSE SIMD):"
grep -A 3 "vec_add:" test_selection.s | head -5
echo ""

echo "=== 3. 指令选择模式速查表 ==="
echo "┌──────────────────┬──────────────────────┬──────────────────────┐"
echo "│ 模式             │ NVPTX                │ x86_64               │"
echo "├──────────────────┼──────────────────────┼──────────────────────┤"
echo "│ mul+add 融合     │ mad.lo.s32           │ imul + lea           │"
echo "│ 地址模式         │ mul.wide + add       │ (base,idx,scale)     │"
echo "│ 条件选择         │ max.s32              │ cmovgl               │"
echo "│ 向量加法         │ 标量化 (4×add)       │ paddd (SSE)          │"
echo "└──────────────────┴──────────────────────┴──────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
