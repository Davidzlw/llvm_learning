#!/bin/bash
# Chapter 7 实践脚本：探索 LLVM IR

cd "$(dirname "$0")"

echo "============================================"
echo "  Chapter 7: Understanding LLVM IR 实践"
echo "============================================"
echo ""

# ============================================
# 实验1: C → LLVM IR 映射
# ============================================
echo ">>> 实验1: C 代码 → LLVM IR (O0)"
echo "----------------------------------------"
echo "从 test_ir_basics.c 生成 IR..."
clang -S -emit-llvm -O0 -Xclang -disable-O0-optnone test_ir_basics.c -o test_ir_basics.ll 2>/dev/null
echo "basic_arithmetic 函数 (O0, alloca 模式):"
sed -n '/define.*basic_arithmetic/,/^}/p' test_ir_basics.ll | head -12
echo ""

# ============================================
# 实验2: mem2reg — alloca → SSA
# ============================================
echo ">>> 实验2: mem2reg 将 alloca 提升为 SSA 寄存器"
echo "----------------------------------------"
echo "basic_arithmetic (mem2reg 后):"
opt -passes=mem2reg < test_ir_basics.ll -S 2>/dev/null | sed -n '/define.*basic_arithmetic/,/^}/p'
echo ""

echo "control_flow (mem2reg 后，注意 phi 指令):"
opt -passes=mem2reg < test_ir_basics.ll -S 2>/dev/null | sed -n '/define.*control_flow/,/^}/p'
echo ""

# ============================================
# 实验3: instnamer — 命名所有变量
# ============================================
echo ">>> 实验3: instnamer 消除隐式编号变量"
echo "----------------------------------------"
echo "basic_arithmetic (instnamer 后):"
opt -passes=mem2reg,instnamer < test_ir_basics.ll -S 2>/dev/null | sed -n '/define.*basic_arithmetic/,/^}/p'
echo ""

# ============================================
# 实验4: O0 vs O2 优化对比
# ============================================
echo ">>> 实验4: O0 vs O2 优化效果对比"
echo "----------------------------------------"
echo "O0 (mem2reg 后) 指令数: $(opt -passes=mem2reg < test_ir_basics.ll -S 2>/dev/null | grep -cE '^\s+%')"
echo "O2 指令数: $(opt -passes='default<O2>' < test_ir_basics.ll -S 2>/dev/null | grep -cE '^\s+%')"
echo ""
echo "O2 优化后的 array_sum (向量化 + intrinsic):"
opt -passes="default<O2>" < test_ir_basics.ll -S 2>/dev/null | sed -n '/define.*array_sum/,/^}/p'
echo ""
echo "O2 优化后的 loop_sum (循环消除，闭式公式):"
opt -passes="default<O2>" < test_ir_basics.ll -S 2>/dev/null | sed -n '/define.*loop_sum/,/^}/p'
echo ""

# ============================================
# 实验5: CUDA IR 中的 intrinsics
# ============================================
echo ">>> 实验5: CUDA IR 中的 target-specific intrinsics"
echo "----------------------------------------"
if [ -f /home/zhanglw/Code/llvm_learning/test-cuda-nvptx64-nvidia-cuda-sm_89.ll ]; then
    echo "NVPTX intrinsics:"
    grep -E "declare.*llvm\.nvvm" /home/zhanglw/Code/llvm_learning/test-cuda-nvptx64-nvidia-cuda-sm_89.ll
    echo ""
    echo "target triple:"
    grep "target triple" /home/zhanglw/Code/llvm_learning/test-cuda-nvptx64-nvidia-cuda-sm_89.ll
    echo "target datalayout:"
    grep "target datalayout" /home/zhanglw/Code/llvm_learning/test-cuda-nvptx64-nvidia-cuda-sm_89.ll
else
    echo "(CUDA IR 文件不可用)"
fi
echo ""

# ============================================
# 实验6: bitcode vs 文本 IR
# ============================================
echo ">>> 实验6: bitcode (.bc) vs 文本 IR (.ll)"
echo "----------------------------------------"
opt -passes=mem2reg < test_ir_basics.ll -o test_basics.bc 2>/dev/null
echo "文本 IR 大小: $(ls -lh test_ir_basics.ll | awk '{print $5}')"
echo "bitcode 大小: $(ls -lh test_basics.bc | awk '{print $5}')"
echo "bitcode 可恢复: $(opt -S < test_basics.bc 2>/dev/null | head -1)"
echo ""

# ============================================
# 实验7: Quiz - 隐式变量冲突
# ============================================
echo ">>> 实验7: Quiz - 隐式变量编号冲突"
echo "----------------------------------------"
echo "错误示例 (%2 与隐式基本块编号冲突):"
echo 'define i32 @add(i32 %0, i32 %1) {
  %2 = add i32 %0, %1
  ret i32 %2
}' > /tmp/quiz_err.ll
opt < /tmp/quiz_err.ll -S 2>&1 | head -3
echo ""
echo "修复后 (给基本块命名):"
opt < quiz2.ll -S 2>/dev/null
echo ""

echo "============================================"
echo "  实践完成"
echo "============================================"
