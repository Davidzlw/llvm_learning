#!/bin/bash
# Chapter 10 实践脚本：LLVM IR Pass 调试工具
# 用法: bash debug_passes.sh

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo " Chapter 10: Hands-On Debugging LLVM IR Passes"
echo "=============================================="
echo ""

# --- 1. print-after-all ---
echo "=== 1. print-after-all: 观察每个 Pass 后的 IR ==="
opt -passes="instcombine" -print-after-all test_debug.ll -S 2>&1 | grep "IR Dump After" | head -5
echo ""

# --- 2. print-before 指定 Pass ---
echo "=== 2. print-before=simplifycfg: 在 simplifycfg 之前打印 IR ==="
opt -passes="instcombine,simplifycfg" -print-before=simplifycfg test_debug.ll -S 2>&1 | grep "IR Dump Before" | head -3
echo ""

# --- 3. opt-bisect-limit ---
echo "=== 3. opt-bisect-limit: 二分定位 Pass ==="
echo "限制到前 5 个 Pass:"
opt -passes="default<O2>" -opt-bisect-limit=5 test_debug.ll -S 2>&1 | grep "BISECT:" | head -8
echo ""

# --- 4. verify-each ---
echo "=== 4. verify-each: 每个 Pass 后验证 IR ==="
opt -passes="default<O2>" -verify-each test_debug.ll -S -o /dev/null 2>&1 && echo "验证通过！"
echo ""

# --- 5. llvm-extract ---
echo "=== 5. llvm-extract: 提取函数/基本块 ==="
echo "提取 @compute 函数:"
llvm-extract -func=compute test_debug.ll -S 2>&1 | head -5
echo "..."
echo ""
echo "提取 @compute:then 基本块:"
llvm-extract -bb=compute:then test_debug.ll -S 2>&1 | head -8
echo "..."
echo ""

# --- 6. llvm-reduce ---
echo "=== 6. llvm-reduce: 自动缩减测试用例 ==="
if [ -f test_reduce.ll ] && [ -f test_interesting.sh ]; then
    echo "原始文件:"
    wc -l test_reduce.ll
    echo ""
    echo "运行 llvm-reduce..."
    llvm-reduce --test=./test_interesting.sh test_reduce.ll -o reduced.ll 2>&1 | grep -E "SUCCESS|Done" | head -5
    echo ""
    echo "缩减结果:"
    cat reduced.ll
else
    echo "(测试文件不存在，跳过)"
fi
echo ""

# --- 7. 调试工具汇总 ---
echo "=== 7. 调试工具速查表 ==="
echo "┌──────────────────┬────────────────────────────────────────┐"
echo "│ 工具             │ 用途                                   │"
echo "├──────────────────┼────────────────────────────────────────┤"
echo "│ print-after-all  │ 每个 Pass 后打印 IR                    │"
echo "│ print-before     │ 指定 Pass 前打印 IR                    │"
echo "│ debug-only       │ 打印特定 Pass 的调试日志               │"
echo "│ stats            │ 打印 Pass 统计信息                     │"
echo "│ opt-bisect-limit │ 二分定位问题 Pass                      │"
echo "│ verify-each      │ 每个 Pass 后验证 IR 合法性             │"
echo "│ llvm-extract     │ 提取函数/基本块为独立模块              │"
echo "│ llvm-reduce      │ 自动缩减测试用例                       │"
echo "│ bugpoint         │ 传统缩减工具（LLVM 19 仍可用）         │"
echo "│ LLDB             │ 交互式调试器                           │"
echo "└──────────────────┴────────────────────────────────────────┘"
echo ""

echo "=============================================="
echo " 实践完成！"
echo "=============================================="
