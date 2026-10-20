#!/bin/bash
# ch04 实践脚本

cd "$(dirname "$0")"

echo "=== Chapter 4: 第一个优化 Pass ==="
echo ""

# 检查 LLVM 工具
if ! command -v llvm-config &> /dev/null; then
    echo "错误: 未找到 llvm-config，请确保 LLVM 已安装并在 PATH 中"
    exit 1
fi

echo "LLVM 版本: $(llvm-config --version)"
echo ""

# 编译 Pass
echo ">>> 编译 Pass..."
clang++ -shared -fPIC -o ConstFoldPass.so const_fold_pass.cpp \
    $(llvm-config --cxxflags --ldflags --libs core support) \
    -Wno-pass-failed 2>/dev/null

if [ $? -ne 0 ]; then
    echo "编译失败，尝试使用不同的 LLVM 配置..."
    clang++ -shared -fPIC -o ConstFoldPass.so const_fold_pass.cpp \
        $(llvm-config --cxxflags --ldflags --libs) \
        -Wno-pass-failed
fi

if [ ! -f ConstFoldPass.so ]; then
    echo "错误: 编译失败"
    exit 1
fi

echo "编译成功: ConstFoldPass.so"
echo ""

# 显示原始 IR
echo ">>> 原始 IR:"
echo "----------------------------------------"
cat test_input.ll
echo "----------------------------------------"
echo ""

# 运行 Pass
echo ">>> 运行常量折叠 Pass..."
echo "----------------------------------------"
opt -load ./ConstFoldPass.so -const-fold < test_input.ll -S 2>&1
echo "----------------------------------------"
echo ""

echo "=== 完成 ==="
echo ""
echo "提示:"
echo "  - 观察 %a, %b, %c 是否被替换为常量 30"
echo "  - 注意 test_partial 函数中的变量部分无法折叠"
echo ""
echo "下一步:"
echo "  - 修改 const_fold_pass.cpp，支持更多操作（shl, and, or）"
echo "  - 查看 ch05 了解 Pass Manager 的工作原理"
