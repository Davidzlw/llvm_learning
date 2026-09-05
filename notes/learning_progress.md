# LLVM 学习笔记

## 学习进度

### Chapter 1: Building LLVM and Understanding the Directory Structure
- **状态**: ✅ 已完成
- **日期**: 2026-09-05
- **笔记**: [Chapter 1 Notes](examples/part1_getting_started/ch01_building_llvm/README.md)
- **测验**: [Chapter 1 Quiz](examples/part1_getting_started/ch01_building_llvm/quiz.md)

**关键收获**:
1. LLVM 最初代表 Low-Level Virtual Machine，现在已成为编译器基础设施的代名词
2. LLVM 项目包含多个子项目：llvm（核心）、clang（C/C++前端）、lld（链接器）等
3. 核心目录结构：
   - `llvm/include/llvm/IR/` - LLVM IR 定义
   - `llvm/lib/Target/NVPTX/` - NVIDIA PTX 后端
   - `llvm/lib/Passes/` - 优化 Pass 实现
4. LLVM IR 有三种形式：文本(.ll)、二进制(.bc)、内存表示
5. 构建工具链：Git → CMake → Ninja → C/C++ Toolchain

---

### Chapter 3: Compiler Basics and How They Map to LLVM APIs
- **状态**: ⏳ 待学习
- **重要性**: ⭐⭐⭐⭐⭐

---

### Chapter 7: Understanding LLVM IR
- **状态**: ⏳ 待学习
- **重要性**: ⭐⭐⭐⭐⭐

---

## 环境信息

- **GPU**: NVIDIA GeForce RTX 4090 D (sm_89)
- **Driver**: 580.126.09
- **CUDA**: 13.0 (V13.0.48)
- **LLVM**: 19.1.7
- **Clang**: 19.1.7

## 编译链命令

```bash
# 完整流程
.cu → .ll → .bc → .ptx → .cubin

# 具体命令
clang -x cuda --cuda-gpu-arch=sm_89 --cuda-device-only -S -emit-llvm test.cu -o test.ll
llvm-as test.ll -o test.bc
llc test.bc -march=nvptx64 -mcpu=sm_89 -filetype=asm -o test.ptx
ptxas test.ptx -arch=sm_89 -o test.cubin
```

## 重要概念

### 编译器三层架构
1. **前端 (Frontend)**: 源代码 → LLVM IR
2. **中端 (Middle-end)**: 优化 LLVM IR
3. **后端 (Backend)**: LLVM IR → 机器码

### LLVM IR vs Machine IR
- **LLVM IR**: 目标无关，高级抽象，SSA 形式
- **Machine IR**: 目标相关，引入寄存器和机器指令

### 关键工具
- `clang`: C/C++/CUDA 前端编译器
- `opt`: LLVM IR 优化器
- `llc`: 后端代码生成器
- `llvm-as/llvm-dis`: IR 汇编/反汇编

## 学习资源

- **书籍**: LLVM Code Generation (2025) by Quentin Colombet
- **官方文档**: https://llvm.org/docs/
- **NVPTX 后端**: https://llvm.org/docs/NVPTXUsage.html
- **书籍代码**: https://github.com/PacktPublishing/LLVM-Code-Generation

## 待探索问题

1. NVPTX 后端如何处理 GPU 特有的概念（warp、shared memory）？
2. LLVM IR 中的 `llvm.nvvm.*` intrinsics 是什么？
3. PTX 和 SASS 之间有什么关系？
4. 如何编写自定义的优化 Pass？
5. TableGen 是如何描述目标机器特性的？

## 学习笔记模板

### Chapter X: [标题]

**日期**: YYYY-MM-DD

**主要内容**:
- 

**关键概念**:
- 

**代码示例**:
```
```

**问题和思考**:
- 

**练习**:
- [ ] 
