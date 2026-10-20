#!/bin/bash
# Chapter 19 实践脚本：观察寄存器分配
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 19: Register Allocation"
echo "=============================================="
echo ""

cat > test_regalloc.ll << 'EOF'
define i32 @high_pressure(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e) {
  %t1 = add i32 %a, %b
  %t2 = add i32 %c, %d
  %t3 = mul i32 %t1, %t2
  %t4 = add i32 %t3, %e
  %t5 = sub i32 %t4, %a
  %t6 = mul i32 %t5, %b
  %t7 = add i32 %t6, %c
  ret i32 %t7
}

define i32 @long_live(i32 %x) {
  %a = add i32 %x, 1
  %b = add i32 %a, 2
  %c = add i32 %b, 3
  %d = add i32 %c, 4
  %e = add i32 %d, 5
  %f = add i32 %e, 6
  %g = add i32 %f, 7
  %h = add i32 %g, 8
  %i = add i32 %h, 9
  %j = add i32 %i, 10
  ret i32 %j
}

define i32 @phi_merge(i32 %a, i32 %b, i1 %cond) {
  br i1 %cond, label %then, label %else

then:
  %t1 = add i32 %a, 10
  br label %merge

else:
  %t2 = add i32 %b, 20
  br label %merge

merge:
  %result = phi i32 [%t1, %then], [%t2, %else]
  ret i32 %result
}
EOF

echo "=== 1. NVPTX 寄存器分配 ==="
llc -march=nvptx64 -mcpu=sm_89 test_regalloc.ll -o test_regalloc.ptx 2>/dev/null
echo "high_pressure (多变量):"
grep -A 8 "high_pressure:" test_regalloc.ptx | head -10
echo ""
echo "long_live (常量折叠):"
grep -A 4 "long_live:" test_regalloc.ptx | head -6
echo ""

echo "=== 2. x86_64 寄存器分配 ==="
llc -march=x86-64 test_regalloc.ll -o test_regalloc.s 2>/dev/null
echo "high_pressure (物理寄存器):"
grep -A 6 "high_pressure:" test_regalloc.s | head -8
echo ""
echo "long_live (优化):"
grep -A 3 "long_live:" test_regalloc.s | head -5
echo ""

echo "=== 3. 寄存器分配速查表 ==="
echo "┌──────────────────┬──────────────────────────────────────────┐"
echo "│ 概念             │ 说明                                     │"
echo "├──────────────────┼──────────────────────────────────────────┤"
echo "│ Slot Index       │ 指令编号 + 阶段 (B/E/R/D)               │"
echo "│ Live Interval    │ 虚拟寄存器活跃区间                       │"
echo "│ VNInfo           │ SSA 值定义信息                           │"
echo "│ Spill            │ 寄存器溢出到内存                         │"
echo "│ Coalescing       │ 合并 COPY 指令                           │"
echo "│ Phi 消除         │ 通过分支或条件移动实现                   │"
echo "└──────────────────┴──────────────────────────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
