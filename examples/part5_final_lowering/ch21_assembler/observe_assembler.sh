#!/bin/bash
# Chapter 21 实践脚本：观察汇编器
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 21: Assembler"
echo "=============================================="
echo ""

cat > test_assembler.ll << 'EOF'
define i32 @simple_add(i32 %a, i32 %b) {
  %sum = add i32 %a, %b
  ret i32 %sum
}

define i32 @with_call(i32 %x) {
  %ret = call i32 @external_func(i32 %x)
  ret i32 %ret
}

declare i32 @external_func(i32)
EOF

echo "=== 1. 生成汇编 ==="
llc -march=x86-64 test_assembler.ll -o test_assembler.s 2>/dev/null
echo "汇编输出 (with_call):"
grep -A 6 "with_call:" test_assembler.s | head -8
echo ""

echo "=== 2. 生成 Object 文件 ==="
llc -march=x86-64 -filetype=obj test_assembler.ll -o test_assembler.o 2>/dev/null
echo "Object 文件:"
ls -la test_assembler.o
echo ""

echo "=== 3. 反汇编 ==="
llvm-objdump -d test_assembler.o 2>/dev/null | head -15
echo ""

echo "=== 4. 重定位信息 ==="
llvm-readelf -r test_assembler.o 2>/dev/null
echo ""

echo "=== 5. 符号表 ==="
llvm-nm test_assembler.o 2>/dev/null
echo ""

echo "=== 6. 汇编器流程速查表 ==="
echo "┌──────────────────┬──────────────────────────────────────────┐"
echo "│ 步骤             │ 说明                                     │"
echo "├──────────────────┼──────────────────────────────────────────┤"
echo "│ 解析             │ 文本汇编 → MCInst                        │"
echo "│ 编码             │ MCInst → 二进制 + Fixup                  │"
echo "│ 写入             │ 二进制 + 重定位 → ELF/Mach-O/COFF        │"
echo "│ Fixup            │ 未解析的地址引用                         │"
echo "│ 重定位           │ 链接器解析符号地址                       │"
echo "└──────────────────┴──────────────────────────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
