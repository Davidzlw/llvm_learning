#!/bin/bash
# Chapter 16 实践脚本：观察 Legalization Phase
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 16: Legalization Phase"
echo "=============================================="
echo ""

cat > test_legalize.ll << 'EOF'
define i8 @add_i8(i8 %a, i8 %b) {
  %sum = add i8 %a, %b
  ret i8 %sum
}

define i64 @add_i64(i64 %a, i64 %b) {
  %sum = add i64 %a, %b
  ret i64 %sum
}

define <3 x i8> @add_vec3(<3 x i8> %a, <3 x i8> %b) {
  %sum = add <3 x i8> %a, %b
  ret <3 x i8> %sum
}

define float @add_float(float %a, float %b) {
  %sum = fadd float %a, %b
  ret float %sum
}
EOF

echo "=== 1. NVPTX 类型合法化 ==="
llc -march=nvptx64 -mcpu=sm_89 test_legalize.ll -o test_legalize.ptx 2>/dev/null
echo "i8 add (提升为 i16):"
grep -A 6 "add_i8:" test_legalize.ptx | head -8
echo ""
echo "i64 add (拆分为两个 i32):"
grep -A 8 "add_i64:" test_legalize.ptx | head -10
echo ""

echo "=== 2. x86_64 类型合法化 ==="
llc -march=x86-64 test_legalize.ll -o test_legalize.s 2>/dev/null
echo "i8 add (32位寄存器):"
grep -A 4 "add_i8:" test_legalize.s | head -6
echo ""
echo "i64 add (原生64位):"
grep -A 3 "add_i64:" test_legalize.s | head -5
echo ""

echo "=== 3. 向量类型合法化 ==="
echo "x86_64 <3 x i8> (打包到32位):"
grep -A 15 "add_vec3:" test_legalize.s | head -18
echo ""

echo "=== 4. 浮点操作合法化 ==="
echo "NVPTX float add:"
grep -A 5 "add_float:" test_legalize.ptx | head -7
echo ""
echo "x86_64 float add (SSE):"
grep -A 3 "add_float:" test_legalize.s | head -5
echo ""

echo "=== 5. 合法化动作速查表 ==="
echo "┌──────────────┬──────────────────────────────────────────┐"
echo "│ 动作         │ 说明                                     │"
echo "├──────────────┼──────────────────────────────────────────┤"
echo "│ Legal        │ 目标原生支持                             │"
echo "│ Promote      │ 类型提升（小→大）                        │"
echo "│ Expand       │ 操作展开                                 │"
echo "│ Soften       │ 浮点→整数                                │"
echo "│ Scalarize    │ 向量→标量                                │"
echo "│ Split        │ 拆分类型                                 │"
echo "│ Widen        │ 扩展类型                                 │"
echo "│ LibCall      │ 库函数调用                               │"
echo "│ Custom       │ 自定义实现                               │"
echo "└──────────────┴──────────────────────────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
