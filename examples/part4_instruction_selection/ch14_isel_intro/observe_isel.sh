#!/bin/bash
# Chapter 14 实践脚本：观察指令选择
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 14: Instruction Selection"
echo "=============================================="
echo ""

cat > test_isel.ll << 'EOF'
define i32 @add(i32 %a, i32 %b) {
  %sum = add i32 %a, %b
  ret i32 %sum
}

define i32 @mul_add(i32 %a, i32 %b, i32 %c) {
  %mul = mul i32 %a, %b
  %sum = add i32 %mul, %c
  ret i32 %sum
}
EOF

echo "=== 1. NVPTX 指令选择结果 ==="
llc -march=nvptx64 -mcpu=sm_89 test_isel.ll -o test_isel.ptx 2>/dev/null
echo "PTX (mad.lo.s32 = fused multiply-add):"
grep -A 5 "mul_add" test_isel.ptx | head -8
echo ""

echo "=== 2. x86_64 指令选择结果 ==="
llc -march=x86-64 test_isel.ll -o test_isel.s 2>/dev/null
echo "x86_64 (leal = load-effective-address):"
grep -A 3 "^add:" test_isel.s | head -5
echo ""

echo "=== 3. MIR 指令选择后 ==="
llc -march=nvptx64 -mcpu=sm_89 -stop-after=finalize-isel test_isel.ll -o - 2>/dev/null | \
    grep -A 8 "^body:" | head -10
echo ""

echo "=== 4. 指令选择框架对比 ==="
echo "┌──────────────┬──────────────┬──────────────┬──────────────┐"
echo "│ 特性         │ FastISel     │ SDISel       │ GlobalISel   │"
echo "├──────────────┼──────────────┼──────────────┼──────────────┤"
echo "│ 编译速度     │ 最快         │ 较慢         │ 中等         │"
echo "│ 代码质量     │ 一般         │ 最好         │ 好           │"
echo "│ IR 表示      │ LLVM IR      │ SelectionDAG │ Machine IR   │"
echo "│ 架构         │ 单一 Pass    │ 单一 Pass    │ 模块化       │"
echo "└──────────────┴──────────────┴──────────────┴──────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
