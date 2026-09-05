# Chapter 1: Building LLVM and Understanding the Directory Structure

## 学习目标

完成本章学习后，你将能够：
- ✅ 理解编译器的不同组件
- ✅ 构建和测试 LLVM 项目
- ✅ 导航 LLVM 的目录结构并定位不同组件的实现
- ✅ 为 LLVM 项目做贡献

---

## 1.1 技术需求

### 构建 LLVM 20.1.0 所需的工具

| 工具 | 最低版本要求 |
|------|------------|
| Git | 无特定要求 |
| C/C++ 工具链 | >=Clang 5.0, >=Apple Clang 10.0, >=GCC 7.4, >=Visual Studio 2019 16.8 |
| CMake | >=3.20.0 |
| Ninja | 无特定要求 |
| Python | >=3.8 |

### 我们的环境（LLVM 19.1.7）

```bash
# 检查已安装的工具
clang --version       # Clang 19.1.7 ✅
cmake --version       # 应该已安装
ninja --version       # 应该已安装
python3 --version     # 应该已安装
git --version         # 已安装 ✅
```

---

## 1.2 工具的作用

构建 LLVM 的流程图：

```
1. Git        → 获取源代码
2. CMake      → 为特定驱动（如 Ninja）和 C/C++ 工具链生成构建系统
3. Ninja      → 驱动构建过程
4. C/C++ 工具链 → 编译编译器
5. Python     → 驱动测试执行
```

---

## 1.3 LLVM 目录结构概览

### 高层目录结构

LLVM 项目包含多个子项目，最重要的有：

```
llvm-project/
├── llvm/           # 核心 LLVM 项目和库
├── clang/          # C/C++/Objective-C 编译器前端
├── lld/            # LLVM 链接器
├── lldb/           # LLVM 调试器
├── compiler-rt/    # 编译器运行时库
├── libcxx/         # C++ 标准库实现
├── libcxxabi/      # C++ ABI 支持
├── libunwind/      # 栈展开库
├── polly/          # 多面体优化
├── mlir/           # 多级中间表示
└── ...
```

### 核心 LLVM 项目结构

```
llvm/
├── include/        # 公共头文件
│   └── llvm/
│       ├── IR/           # LLVM IR 定义
│       ├── CodeGen/      # 代码生成基础设施
│       ├── Passes/       # Pass 定义
│       ├── Support/      # 支持库
│       └── Target/       # 目标后端
├── lib/            # 库实现
│   ├── IR/               # LLVM IR 实现
│   ├── CodeGen/          # 代码生成核心
│   ├── Passes/           # 优化 Pass 实现
│   ├── Target/           # 目标后端实现
│   │   └── NVPTX/        # NVIDIA PTX 后端 ⭐
│   └── Support/          # 支持库实现
├── tools/          # 命令行工具
│   ├── opt/              # 优化器
│   ├── llc/              # 后端代码生成
│   ├── lli/              # LLVM IR 解释器
│   ├── llvm-as/          # 汇编器（.ll -> .bc）
│   ├── llvm-dis/         # 反汇编器（.bc -> .ll）
│   └── llvm-config/      # 配置工具
├── unittests/      # 单元测试
├── test/           # 功能测试（lit 测试）
└── docs/           # 文档
```

---

## 1.4 重要组件详解

### 1.4.1 通用 LLVM 基础设施

**位置**: `llvm/lib/IR/`, `llvm/lib/Support/`

核心类和概念：
- `Module` - 编译单元的最高级容器
- `Function` - 函数定义
- `BasicBlock` - 基本块
- `Instruction` - 指令
- `Value` - 所有值的基类
- `Type` - 类型系统

### 1.4.2 LLVM IR 工作

**位置**: `llvm/include/llvm/IR/`, `llvm/lib/IR/`

关键文件：
- `IRBuilder.h` - 构建 IR 的辅助类
- `Instructions.h` - 指令定义
- `DerivedTypes.h` - 派生类型
- `Constants.h` - 常量定义

### 1.4.3 通用后端基础设施

**位置**: `llvm/lib/CodeGen/`

关键组件：
- `MachineFunction.cpp` - Machine IR 函数表示
- `MachineBasicBlock.cpp` - Machine 基本块
- `MachineInstr.cpp` - Machine 指令
- `SelectionDAG/` - 指令选择 DAG
- `RegisterAllocators.cpp` - 寄存器分配器

### 1.4.4 目标特定构造

**位置**: `llvm/lib/Target/<target>/`

以 NVPTX 为例：
```
llvm/lib/Target/NVPTX/
├── NVPTXTargetMachine.cpp    # 目标机器定义
├── NVPTXInstrInfo.td         # 指令定义（TableGen）
├── NVPTXRegisterInfo.td      # 寄存器定义（TableGen）
├── NVPTXInstrInfo.cpp        # 指令信息实现
├── NVPTXRegisterInfo.cpp     # 寄存器信息实现
└── NVPTXISelLowering.cpp     # 指令选择合法化
```

---

## 1.5 构建 LLVM（了解即可）

虽然我们已经有了预编译的 LLVM 19.1.7，但了解构建过程很重要：

```bash
# 典型构建步骤（仅供参考）
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir build && cd build

# 配置构建
cmake -G Ninja ../llvm \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86;NVPTX"

# 构建
ninja
```

---

## 1.6 测试 LLVM

LLVM 使用两个测试框架：

### 1.6.1 Google Test（单元测试）

**位置**: `llvm/unittests/`

```bash
# 运行所有单元测试
ninja check-llvm-unit
```

### 1.6.2 LLVM Integrated Tester (lit)

**位置**: `llvm/test/`

lit 是 LLVM 的功能测试框架，使用 FileCheck 验证输出。

```bash
# 运行所有功能测试
ninja check-llvm

# 运行特定测试
llvm-lit llvm/test/Transforms/InstCombine/
```

### 测试指令示例

```llvm
; RUN: opt -instcombine %s -S | FileCheck %s

; CHECK-LABEL: @test_function(
; CHECK:   %result = add i32 %a, %b
; CHECK:   ret i32 %result
```

---

## 1.7 实践练习

### 练习 1：探索 LLVM 源码

```bash
# 进入 LLVM 源码目录
cd /Code/llvm-source/llvm-project

# 查看顶层目录
ls -la

# 查看 llvm 子目录
ls -la llvm/

# 查看 NVPTX 后端
ls -la llvm/lib/Target/NVPTX/
```

### 练习 2：查找关键文件

```bash
# 查找 LLVM IR 相关头文件
find llvm/include/llvm/IR -name "*.h" | head -20

# 查找 Pass 实现
find llvm/lib/Passes -name "*.cpp" | head -20

# 查找 NVPTX 相关文件
find llvm/lib/Target/NVPTX -type f
```

### 练习 3：理解我们的编译链

回顾我们已经成功的编译链：

```bash
cd /Code/llvm_learning

# Step 1: .cu -> .ll
clang -x cuda --cuda-gpu-arch=sm_89 --cuda-device-only -S -emit-llvm test.cu -o test.ll

# Step 2: .ll -> .bc
llvm-as test.ll -o test.bc

# Step 3: .bc -> .ptx
llc test.bc -march=nvptx64 -mcpu=sm_89 -filetype=asm -o test.ptx

# Step 4: .ptx -> .cubin
ptxas test.ptx -arch=sm_89 -o test.cubin
```

---

## 1.8 关键概念总结

### 编译器组件

1. **前端 (Frontend)** - 解析源代码，生成 LLVM IR
   - 例如：Clang (C/C++), flang (Fortran), rustc (Rust)

2. **中端 (Middle-end)** - 优化 LLVM IR
   - Pass 管线，各种优化

3. **后端 (Backend)** - 将 LLVM IR 转换为机器码
   - 指令选择、寄存器分配、指令调度

### LLVM IR 的三种形式

1. **文本形式 (.ll)** - 人类可读
2. **二进制形式 (.bc)** - 位码，紧凑
3. **内存形式** - API 操作的对象

### 重要工具

- `clang` - C/C++/CUDA 编译器前端
- `opt` - LLVM IR 优化器
- `llc` - LLVM 后端代码生成器
- `llvm-as` - LLVM IR 汇编器
- `llvm-dis` - LLVM IR 反汇编器

---

## 1.9 下一步

- [ ] 阅读 Chapter 3: Compiler Basics and LLVM APIs
- [ ] 阅读 Chapter 7: Understanding LLVM IR ⭐⭐⭐
- [ ] 探索 LLVM 源码中的 NVPTX 后端
- [ ] 尝试修改 test.ll 并观察影响

---

## 参考资源

- LLVM 官方文档: https://llvm.org/docs/
- Getting Started: https://llvm.org/docs/GettingStarted.html
- NVPTX 后端: https://llvm.org/docs/NVPTXUsage.html
- 书籍 GitHub 仓库: https://github.com/PacktPublishing/LLVM-Code-Generation
