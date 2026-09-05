#!/bin/bash
# run_opt_passes.sh - 运行 LLVM 优化 Pass
# Usage: ./run_opt_passes.sh <input.ll> [pass] [output.ll]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.ll> [pass] [output.ll]"
    echo "Available passes: O1, O2, O3, instcombine, mem2reg, dce, gvn, sccp"
    echo "Example: $0 test.ll O2 test_opt.ll"
    exit 1
fi

INPUT=$1
PASS=${2:-"O2"}
BASENAME=$(basename "$INPUT" .ll)
OUTPUT=${3:-"${BASENAME}_${PASS}.ll"}

echo "=== Running optimization pass: $PASS ==="
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo ""

if [[ "$PASS" =~ ^O[0-3]$ ]]; then
    opt -"$PASS" "$INPUT" -o "$OUTPUT"
else
    opt -"$PASS" "$INPUT" -o "$OUTPUT"
fi

echo "SUCCESS: $OUTPUT generated"
ls -lh "$OUTPUT"
echo ""
echo "Diff summary:"
wc -l "$INPUT" "$OUTPUT"
