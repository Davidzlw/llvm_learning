#!/bin/bash
# Chapter 6 实践脚本：TableGen 基础

cd "$(dirname "$0")"

echo "============================================"
echo "  Chapter 6: TableGen 实践"
echo "============================================"
echo ""

# 检查工具
if ! command -v llvm-tblgen &> /dev/null; then
    echo "错误: 未找到 llvm-tblgen"
    exit 1
fi

echo "llvm-tblgen 版本: $(llvm-tblgen --version 2>&1 | head -1)"
echo ""

# ============================================
# 实验1: 基础 records
# ============================================
echo ">>> 实验1: 基础 records (person.td)"
echo "----------------------------------------"
echo "输入文件:"
cat person.td
echo ""
echo "输出 (llvm-tblgen person.td):"
llvm-tblgen person.td 2>&1
echo ""

# ============================================
# 实验2: multiclass 和 defm
# ============================================
echo ">>> 实验2: multiclass 和 defm (multiclass_example.td)"
echo "----------------------------------------"
echo "输入文件:"
cat multiclass_example.td
echo ""
echo "输出 (llvm-tblgen multiclass_example.td):"
llvm-tblgen multiclass_example.td 2>&1
echo ""

# ============================================
# 实验3: 查看 NVPTX 后端真实 TableGen 文件
# ============================================
echo ">>> 实验3: NVPTX 后端的 TableGen 文件 (真实案例)"
echo "----------------------------------------"
echo "NVPTX.td 前 30 行:"
head -30 /home/zhanglw/Code/xpas/include/NVPTX/NVPTX.td 2>/dev/null || echo "(文件不可用)"
echo ""
echo "关键观察:"
echo "  - include \"llvm/Target/Target.td\" 引入目标无关基础设施"
echo "  - SubtargetFeature 定义 GPU 特性 (sm_89, ptx 版本等)"
echo "  - foreach 批量生成 SM20~SM90 的 feature records"
echo "  - Processor 定义支持的 GPU 架构"
echo ""

# ============================================
# 实验4: llvm-tblgen 可用后端
# ============================================
echo ">>> 实验4: llvm-tblgen 可用后端列表"
echo "----------------------------------------"
llvm-tblgen --help 2>&1 | grep "^\s*--gen-" | head -15
echo "... (更多后端省略)"
echo ""

echo "============================================"
echo "  实践完成"
echo "============================================"
echo ""
echo "核心概念总结:"
echo "  1. TableGen 是一种 DSL，用于生成 records"
echo "  2. class 定义模板，def 实例化 records"
echo "  3. multiclass + defm 一次生成多个 records"
echo "  4. let 语句可以覆盖字段值（作用域规则）"
echo "  5. llvm-tblgen 后端将 records 转换为 .inc C++ 代码"
echo "  6. 真实后端(NVPTX)使用 TableGen 描述寄存器、指令、特性"
echo ""
echo "下一步:"
echo "  - 查看 ch07 了解 LLVM IR 的深入知识"
echo "  - 在 LLVM 源码中探索更多 .td 文件的用法"
