#!/bin/bash
# Chapter 13 实践脚本：观察 Machine Pass Pipeline
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 13: Machine Pass Pipeline"
echo "=============================================="
echo ""

cat > test_pipeline.ll << 'EOF'
define i32 @compute(i32 %a, i32 %b, i32 %c) {
entry:
  %sum1 = add i32 %a, %b
  %sum2 = add i32 %sum1, %c
  %mul = mul i32 %sum2, 2
  %cmp = icmp sgt i32 %mul, 100
  br i1 %cmp, label %then, label %else
then:
  %res1 = add i32 %mul, %a
  ret i32 %res1
else:
  %res2 = sub i32 %mul, %b
  ret i32 %res2
}
EOF

echo "=== 1. NVPTX CodeGen Pipeline ==="
llc -march=nvptx64 -mcpu=sm_89 -debug-pass=Structure test_pipeline.ll -o /dev/null 2>&1 | head -3
echo ""

echo "=== 2. Pre-ISel Passes ==="
llc -march=nvptx64 -mcpu=sm_89 -debug-pass=Structure test_pipeline.ll -o /dev/null 2>&1 | \
    tr ' ' '\n' | grep -E "^\-" | sed -n '1,/nvptx-isel/p' | grep -E "lower|sroa|codegenprepare|nvvm" | sed 's/^/  /'
echo ""

echo "=== 3. Post-ISel Pre-RA ==="
llc -march=nvptx64 -mcpu=sm_89 -debug-pass=Structure test_pipeline.ll -o /dev/null 2>&1 | \
    tr ' ' '\n' | grep -E "^\-" | sed -n '/finalize-isel/,/register-coalescer/p' | head -10 | sed 's/^/  /'
echo ""

echo "=== 4. Register Allocation ==="
llc -march=nvptx64 -mcpu=sm_89 -debug-pass=Structure test_pipeline.ll -o /dev/null 2>&1 | \
    tr ' ' '\n' | grep -E "^\-" | sed -n '/register-coalescer/,/stack-slot-coloring/p' | sed 's/^/  /'
echo ""

echo "=== 5. Post-RA ==="
llc -march=nvptx64 -mcpu=sm_89 -debug-pass=Structure test_pipeline.ll -o /dev/null 2>&1 | \
    tr ' ' '\n' | grep -E "^\-" | sed -n '/stack-slot-coloring/,$p' | head -10 | sed 's/^/  /'
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
