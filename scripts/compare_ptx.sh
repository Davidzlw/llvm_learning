#!/bin/bash
# compare_ptx.sh - 比较不同优化级别的 PTX 输出
# Usage: ./compare_ptx.sh <input.bc>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.bc>"
    echo "Example: $0 test.bc"
    exit 1
fi

INPUT=$1
BASENAME=$(basename "$INPUT" .bc)

echo "=== Generating PTX at different optimization levels ==="
echo "Input: $INPUT"
echo ""

for OPT in O0 O1 O2 O3; do
    OUTPUT="${BASENAME}_${OPT}.ptx"
    echo "Generating $OUTPUT..."
    llc "$INPUT" -march=nvptx64 -mcpu=sm_89 -filetype=asm -"$OPT" -o "$OUTPUT"
done

echo ""
echo "=== File sizes ==="
ls -lh ${BASENAME}_O*.ptx

echo ""
echo "=== Line counts ==="
wc -l ${BASENAME}_O*.ptx

echo ""
echo "=== Comparing O0 vs O3 ==="
diff -u ${BASENAME}_O0.ptx ${BASENAME}_O3.ptx | head -50
