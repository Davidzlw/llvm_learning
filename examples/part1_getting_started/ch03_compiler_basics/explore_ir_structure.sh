#!/bin/bash
# explore_ir_structure.sh - 在 test.ll 中观察 Chapter 3 的概念
# Usage: ./explore_ir_structure.sh

set -e

LL_FILE="/Code/cuda_test/test_e2e.ll"

if [ ! -f "$LL_FILE" ]; then
    echo "ERROR: $LL_FILE not found. Run compile_cu_to_ll.sh first."
    exit 1
fi

echo "=============================================="
echo " Chapter 3 实践：在 LLVM IR 中观察基本结构"
echo "=============================================="
echo ""

echo "=== 1. Module 级别信息 ==="
echo "--- target triple, datalayout, 全局定义 ---"
head -12 "$LL_FILE"
echo ""

echo "=== 2. Function 级别 ==="
echo "--- 查找所有 function 定义 ---"
grep -n "^define\|^declare" "$LL_FILE"
echo ""

echo "=== 3. BasicBlock 级别 ==="
echo "--- 查找基本块标签（函数入口点） ---"
grep -n "^[a-zA-Z_].*:" "$LL_FILE" | head -10
echo ""

echo "=== 4. Instruction 级别 ==="
echo "--- 函数体内的指令（%x = ... 形式） ---"
grep -n "^\s*%" "$LL_FILE" | head -15
echo ""

echo "=== 5. Terminator 指令 ==="
echo "--- 查找 ret/br/switch/unreachable ---"
grep -n "^\s*ret \|^\s*br " "$LL_FILE"
echo ""

echo "=== 6. 全局值和常量 ==="
echo "--- 字符串常量、全局变量 ---"
grep -n "^@\." "$LL_FILE"
echo ""

echo "=== 7. LLVM NVVM Intrinsics ==="
echo "--- GPU 特殊内置函数 ---"
grep -n "llvm.nvvm\|vprintf" "$LL_FILE"
echo ""

echo "=== 8. 完整的函数体 ==="
echo "--- helloKernel 函数 ---"
sed -n '/^define.*helloKernel/,/^}/p' "$LL_FILE"
echo ""

echo "=== 9. 对比不同优化级别的 IR ==="
cd /Code/cuda_test
opt -O0 test_e2e.ll -S -o /tmp/test_O0.ll 2>/dev/null
opt -O2 test_e2e.ll -S -o /tmp/test_O2.ll 2>/dev/null
echo "O0 指令数: $(grep -c '^\s*%' /tmp/test_O0.ll)"
echo "O2 指令数: $(grep -c '^\s*%' /tmp/test_O2.ll)"
echo ""

echo "=== 10. 对比 PTX 中的 Machine IR 概念 ==="
echo "--- 查看 test_e2e.ptx 中的结构 ---"
PTX_FILE="/Code/cuda_test/test_e2e.ptx"
if [ -f "$PTX_FILE" ]; then
    echo "Functions (.entry/.func):"
    grep -n "\.entry\|\.func" "$PTX_FILE"
    echo ""
    echo "Labels (基本块):"
    grep -n "^[A-Z_][A-Z_0-9]*:" "$PTX_FILE" | head -10
    echo ""
    echo "Instructions (指令):"
    grep -c "^\s*[a-z]" "$PTX_FILE"
    echo "条 PTX 指令"
else
    echo "PTX file not found. Run the full compilation chain first."
fi
