#!/bin/bash
# dump_sass.sh - 反汇编 cubin 为 SASS
# Usage: ./dump_sass.sh <input.cubin>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.cubin>"
    echo "Example: $0 test.cubin"
    exit 1
fi

INPUT=$1

echo "=== SASS Disassembly ==="
echo "Input: $INPUT"
echo ""

cuobjdump -sass "$INPUT"
