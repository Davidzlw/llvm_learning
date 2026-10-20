#!/bin/bash
# Chapter 18 实践脚本：观察指令调度
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 18: Instruction Scheduling"
echo "=============================================="
echo ""

cat > test_schedule.ll << 'EOF'
define i32 @chain(i32 %a, i32 %b, i32 %c) {
  %add1 = add i32 %a, %b
  %add2 = add i32 %add1, %c
  %add3 = add i32 %add2, %a
  ret i32 %add3
}

define i32 @parallel(i32 %a, i32 %b, i32 %c, i32 %d) {
  %add1 = add i32 %a, %b
  %add2 = add i32 %c, %d
  %sub1 = sub i32 %a, %c
  %sub2 = sub i32 %b, %d
  %mul1 = mul i32 %add1, %add2
  %add3 = add i32 %sub1, %sub2
  %result = add i32 %mul1, %add3
  ret i32 %result
}

define i32 @memory(i32* %ptr1, i32* %ptr2, i32 %val) {
  %v1 = load i32, i32* %ptr1
  %v2 = load i32, i32* %ptr2
  store i32 %val, i32* %ptr1
  %sum = add i32 %v1, %v2
  ret i32 %sum
}
EOF

echo "=== 1. NVPTX 指令调度 ==="
llc -march=nvptx64 -mcpu=sm_89 test_schedule.ll -o test_schedule.ptx 2>/dev/null
echo "chain (依赖链):"
grep -A 6 "chain:" test_schedule.ptx | head -8
echo ""
echo "parallel (可并行):"
grep -A 10 "parallel:" test_schedule.ptx | head -12
echo ""
echo "memory (load/store):"
grep -A 7 "memory:" test_schedule.ptx | head -9
echo ""

echo "=== 2. x86_64 指令调度 ==="
llc -march=x86-64 test_schedule.ll -o test_schedule.s 2>/dev/null
echo "chain (依赖链):"
grep -A 5 "chain:" test_schedule.s | head -7
echo ""
echo "parallel (可并行):"
grep -A 8 "parallel:" test_schedule.s | head -10
echo ""
echo "memory (load/store):"
grep -A 4 "memory:" test_schedule.s | head -6
echo ""

echo "=== 3. 调度优化速查表 ==="
echo "┌──────────────────┬──────────────────────────────────────────┐"
echo "│ 优化技术         │ 说明                                     │"
echo "├──────────────────┼──────────────────────────────────────────┤"
echo "│ Load 提前        │ 隐藏内存访问延迟                         │"
echo "│ Store 延迟       │ 减少内存依赖冲突                         │"
echo "│ 指令融合         │ mul+add → mad, load+add → 单条指令      │"
echo "│ 独立操作交错     │ 提高指令级并行 (ILP)                     │"
echo "│ 依赖链保持       │ 无法并行，保持顺序                       │"
echo "└──────────────────┴──────────────────────────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
