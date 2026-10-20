#!/bin/bash
# Chapter 5 实践脚本：观察 Pass 流水线

cd "$(dirname "$0")"

echo "============================================"
echo "  Chapter 5: Pass Managers 实践"
echo "============================================"
echo ""

# 检查工具
if ! command -v opt &> /dev/null; then
    echo "错误: 未找到 opt 工具"
    exit 1
fi

echo "LLVM 版本: $(llvm-config --version)"
echo ""

# ============================================
# 实验1: 逐步运行 Pass
# ============================================
echo ">>> 实验1: 逐步运行 Pass"
echo "----------------------------------------"

echo ""
echo "[1a] 原始 IR (main_test 函数):"
grep -A 15 "define i32 @main_test" test_pipeline.ll | head -16

echo ""
echo "[1b] 仅 mem2reg:"
opt -passes=mem2reg < test_pipeline.ll -S 2>/dev/null | grep -A 12 "define i32 @main_test"

echo ""
echo "[1c] mem2reg + instcombine:"
opt -passes="mem2reg,instcombine" < test_pipeline.ll -S 2>/dev/null | grep -A 10 "define i32 @main_test"

echo ""
echo "[1d] 完整 O2 优化:"
opt -passes="default<O2>" < test_pipeline.ll -S 2>/dev/null | grep -A 4 "define.*@main_test"

echo ""
echo ""

# ============================================
# 实验2: 观察 Pass 流水线结构
# ============================================
echo ">>> 实验2: Pass 流水线结构 (-debug-pass-manager)"
echo "----------------------------------------"
opt -passes="mem2reg,instcombine" -debug-pass-manager < test_pipeline.ll -o /dev/null 2>&1 | head -20
echo "... (更多输出省略)"
echo ""

# ============================================
# 实验3: 时间分析
# ============================================
echo ">>> 实验3: Pass 执行时间报告 (-time-passes)"
echo "----------------------------------------"
opt -passes="mem2reg,instcombine" -time-passes < test_pipeline.ll -o /dev/null 2>&1 | head -15
echo ""

# ============================================
# 实验4: O2 流水线统计
# ============================================
echo ">>> 实验4: O2 流水线 Pass 数量"
echo "----------------------------------------"
PASS_COUNT=$(opt -passes="default<O2>" -debug-pass-manager < test_pipeline.ll -o /dev/null 2>&1 | grep "Running pass:" | wc -l)
echo "O2 流水线共执行 ${PASS_COUNT} 个 Pass"
echo ""

# ============================================
# 实验5: 导出流水线列表
# ============================================
echo ">>> 实验5: 导出 Pass 流水线列表 (-print-pipeline-passes)"
echo "----------------------------------------"
opt -passes="mem2reg,instcombine" -print-pipeline-passes < test_pipeline.ll -o /dev/null 2>&1 | head -1
echo ""

echo "============================================"
echo "  实践完成"
echo "============================================"
echo ""
echo "关键观察:"
echo "  1. mem2reg 消除 alloca，将 load/store 转为 SSA 寄存器"
echo "  2. instcombine 进行常量折叠和指令简化 (mul→shl, 合并常量)"
echo "  3. O2 流水线包含 271 个 Pass，InstCombine 占比最高"
echo "  4. 分析 Pass 按需计算并在同一作用域内缓存复用"
echo ""
echo "下一步:"
echo "  - 查看 ch06 了解 TableGen 如何描述目标机器特性"
echo "  - 尝试编写自定义 Pass 并集成到流水线中"
