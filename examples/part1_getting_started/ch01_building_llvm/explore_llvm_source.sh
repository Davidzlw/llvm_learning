#!/bin/bash
# explore_llvm_source.sh - 探索 LLVM 源码结构
# Usage: ./explore_llvm_source.sh

set -e

LLVM_ROOT="/Code/llvm-source/llvm-project"

if [ ! -d "$LLVM_ROOT" ]; then
    echo "ERROR: LLVM source not found at $LLVM_ROOT"
    echo "Please download LLVM source first."
    exit 1
fi

echo "=== LLVM Source Exploration ==="
echo "Root: $LLVM_ROOT"
echo ""

echo "=== Top-level directories ==="
ls -1 "$LLVM_ROOT"
echo ""

echo "=== LLVM core directory ==="
ls -1 "$LLVM_ROOT/llvm"
echo ""

echo "=== LLVM include structure ==="
ls -1 "$LLVM_ROOT/llvm/include/llvm" | head -20
echo ""

echo "=== LLVM lib structure ==="
ls -1 "$LLVM_ROOT/llvm/lib" | head -20
echo ""

echo "=== Target backends ==="
ls -1 "$LLVM_ROOT/llvm/lib/Target"
echo ""

echo "=== NVPTX backend files ==="
ls -lh "$LLVM_ROOT/llvm/lib/Target/NVPTX" | head -20
echo ""

echo "=== Key IR headers ==="
ls -lh "$LLVM_ROOT/llvm/include/llvm/IR" | head -15
echo ""

echo "=== Pass implementations ==="
ls -lh "$LLVM_ROOT/llvm/lib/Passes" | head -15
echo ""

echo "=== Tools ==="
ls -1 "$LLVM_ROOT/llvm/tools" | head -20
