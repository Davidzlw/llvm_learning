#!/bin/bash
# Chapter 15 实践脚本：观察 ABI Lowering
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 15: IR Building Phase (ABI)"
echo "=============================================="
echo ""

cat > test_abi.ll << 'EOF'
declare i32 @external_func(i32 %a, i32 %b, i32 %c)

define i32 @caller(i32 %x, i32 %y) {
  %sum = add i32 %x, %y
  %ret = call i32 @external_func(i32 %sum, i32 %x, i32 %y)
  ret i32 %ret
}

define i32 @callee(i32 %a, i32 %b, i32 %c, i32 %d) {
  %sum1 = add i32 %a, %b
  %sum2 = add i32 %c, %d
  %total = add i32 %sum1, %sum2
  ret i32 %total
}
EOF

echo "=== 1. NVPTX 参数传递 (参数内存) ==="
llc -march=nvptx64 -mcpu=sm_89 test_abi.ll -o test_abi.ptx 2>/dev/null
echo "callee 函数 (ld.param 加载参数):"
grep -A 8 "callee:" test_abi.ptx | head -10
echo ""

echo "=== 2. x86_64 参数传递 (寄存器传参) ==="
llc -march=x86-64 test_abi.ll -o test_abi.s 2>/dev/null
echo "callee 函数 (%edi,%esi,%edx,%ecx):"
grep -A 8 "^callee:" test_abi.s | head -10
echo ""

echo "=== 3. 函数调用序列 ==="
echo "NVPTX callseq:"
grep -A 10 "callseq" test_abi.ptx | head -12
echo ""
echo "x86_64 call:"
grep -B 2 -A 1 "callq" test_abi.s | head -5
echo ""

echo "=== 4. ABI 对比速查表 ==="
echo "┌──────────────┬──────────────────────┬──────────────────────┐"
echo "│ 特性         │ NVPTX                │ x86_64               │"
echo "├──────────────┼──────────────────────┼──────────────────────┤"
echo "│ 参数传递     │ 参数内存 (.param)    │ 寄存器传参           │"
echo "│ 参数加载     │ ld.param.u32         │ 直接读寄存器         │"
echo "│ 调用序列     │ callseq 包裹         │ 直接 call            │"
echo "│ 返回值       │ .param func_retval0  │ %eax                 │"
echo "└──────────────┴──────────────────────┴──────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
