#!/bin/bash
# Chapter 12 实践脚本：观察 MC 层
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 12: Machine Code Layer"
echo "=============================================="
echo ""

cat > test_mc.ll << 'EOF'
define i32 @add(i32 %a, i32 %b) {
  %sum = add i32 %a, %b
  ret i32 %sum
}
EOF

echo "=== 1. llvm-mc 汇编 x86_64 ==="
echo "addl %edi, %esi" | llvm-mc --arch=x86-64 -show-encoding 2>&1
echo ""

echo "=== 2. llvm-mc 反汇编 ==="
echo "0x01, 0xf7" | llvm-mc --arch=x86-64 -disassemble 2>&1
echo ""

echo "=== 3. NVPTX PTX 输出 ==="
llc -march=nvptx64 -mcpu=sm_89 test_mc.ll -filetype=asm -o test_mc.ptx 2>/dev/null
cat test_mc.ptx
echo ""

echo "=== 4. x86_64 汇编输出 ==="
llc -march=x86-64 test_mc.ll -filetype=asm -o test_mc.s 2>/dev/null
cat test_mc.s
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
