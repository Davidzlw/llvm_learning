#!/bin/bash
# Chapter 11 实践脚本：观察 Machine IR
# 用法: bash observe_mir.sh

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 11: Getting Started with the Backend"
echo "=============================================="
echo ""

# --- 1. 生成 MIR ---
echo "=== 1. 生成 NVPTX Machine IR (MIR) ==="
echo "llc -march=nvptx64 -mcpu=sm_89 -stop-after=finalize-isel test_simple.ll"
echo ""
echo "add 函数 body:"
llc -march=nvptx64 -mcpu=sm_89 -stop-after=finalize-isel test_simple.ll -o - 2>/dev/null | \
    sed -n '/^name:.*add$/,/^---$/p' | grep -A 10 "^body:" | head -12
echo ""

# --- 2. x86_64 MIR 对比 ---
echo "=== 2. x86_64 MIR 对比 ==="
echo "x86_64 add 函数 body:"
llc -march=x86-64 -stop-after=finalize-isel test_simple.ll -o - 2>/dev/null | \
    sed -n '/^name:.*add$/,/^---$/p' | grep -A 10 "^body:" | head -12
echo ""

# --- 3. 寄存器类 ---
echo "=== 3. NVPTX 寄存器类 ==="
llc -march=nvptx64 -mcpu=sm_89 -stop-after=finalize-isel test_simple.ll -o - 2>/dev/null | \
    grep "class:" | sort -u | sed 's/^/  /'
echo ""

# --- 4. PTX 输出 ---
echo "=== 4. 最终 PTX 汇编输出 ==="
llc -march=nvptx64 -mcpu=sm_89 test_simple.ll -o test_simple.ptx 2>/dev/null
echo "add 函数 PTX:"
sed -n '/\.visible .func.*add/,/End function/p' test_simple.ptx | head -15
echo ""

# --- 5. x86_64 汇编输出 ---
echo "=== 5. x86_64 汇编输出 ==="
llc -march=x86-64 test_simple.ll -o test_simple.s 2>/dev/null
echo "add 函数汇编:"
sed -n '/^add:/,/End function/p' test_simple.s | head -12
echo ""

# --- 6. 概念速查表 ---
echo "=== 6. Machine IR vs LLVM IR 速查表 ==="
echo "┌──────────────────┬───────────────────────┬───────────────────────┐"
echo "│ 特性             │ LLVM IR               │ Machine IR            │"
echo "├──────────────────┼───────────────────────┼───────────────────────┤"
echo "│ SSA 形式         │ 强制 SSA              │ SSA + non-SSA         │"
echo "│ 寄存器           │ 虚拟寄存器(无限)      │ 虚拟 + 物理寄存器     │"
echo "│ 类型             │ 丰富类型系统          │ 仅位宽(b32/b64等)     │"
echo "│ 指令             │ 目标无关              │ 目标相关(真实指令)    │"
echo "│ 基本块           │ 以 terminator 结束    │ 以 terminator 结束    │"
echo "│ 文本格式         │ .ll                   │ .mir (YAML)           │"
echo "│ 地址空间         │ 显式 addrspace        │ 隐含在指令中          │"
echo "└──────────────────┴───────────────────────┴───────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
