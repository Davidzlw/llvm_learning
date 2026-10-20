#!/bin/bash
# Chapter 20 实践脚本：观察栈布局
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 20: Stack Layout"
echo "=============================================="
echo ""

cat > test_stack.ll << 'EOF'
define i32 @stack_test(i32 %a, i32 %b) {
  %local1 = alloca i32
  %local2 = alloca i32
  store i32 %a, i32* %local1
  store i32 %b, i32* %local2
  %v1 = load i32, i32* %local1
  %v2 = load i32, i32* %local2
  %sum = add i32 %v1, %v2
  ret i32 %sum
}

define i32 @large_stack() {
  %arr = alloca [100 x i32]
  %ptr = getelementptr [100 x i32], [100 x i32]* %arr, i32 0, i32 0
  store i32 999, i32* %ptr
  %val = load i32, i32* %ptr
  ret i32 %val
}
EOF

echo "=== 1. x86_64 栈帧 ==="
llc -march=x86-64 test_stack.ll -o test_stack.s 2>/dev/null
echo "stack_test (局部变量):"
grep -A 6 "stack_test:" test_stack.s | head -8
echo ""
echo "large_stack (大栈帧):"
grep -A 6 "large_stack:" test_stack.s | head -8
echo ""

echo "=== 2. NVPTX 栈帧 ==="
llc -march=nvptx64 -mcpu=sm_89 test_stack.ll -o test_stack.ptx 2>/dev/null
echo "stack_test (参数内存):"
grep -A 5 "stack_test:" test_stack.ptx | head -7
echo ""

echo "=== 3. 栈布局速查表 ==="
echo "┌──────────────────┬──────────────────────────────────────────┐"
echo "│ 组件             │ 说明                                     │"
echo "├──────────────────┼──────────────────────────────────────────┤"
echo "│ TargetFrameLowering │ Prologue/Epilogue 代码序列           │"
echo "│ TargetRegisterInfo  │ Frame Index 展开                     │"
echo "│ PEI Pass            │ 目标无关的栈布局驱动                 │"
echo "│ RegScavenger        │ 寄存器争夺                           │"
echo "│ Emergency Spill     │ 无寄存器时溢出到栈                   │"
echo "└──────────────────┴──────────────────────────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
