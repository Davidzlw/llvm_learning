#!/bin/bash
# compile_cu_to_ll.sh - 将 CUDA 源码编译为 LLVM IR
# Usage: ./compile_cu_to_ll.sh <input.cu> [output.ll]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.cu> [output.ll]"
    echo "Example: $0 test.cu test.ll"
    exit 1
fi

INPUT=$1
BASENAME=$(basename "$INPUT" .cu)
OUTPUT=${2:-"${BASENAME}.ll"}

echo "=== Compiling $INPUT -> $OUTPUT ==="
clang -x cuda --cuda-gpu-arch=sm_89 --cuda-device-only -S -emit-llvm "$INPUT" -o "$OUTPUT"

echo "SUCCESS: $OUTPUT generated"
ls -lh "$OUTPUT"
echo ""
echo "First 20 lines:"
head -20 "$OUTPUT"
