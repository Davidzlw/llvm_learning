# CUDA-LLVM-PTX-CUBIN 学习项目

基于《LLVM Code Generation (2025)》教程的 CUDA 编译链学习项目。

## 环境信息

- **GPU**: NVIDIA GeForce RTX 4090 D (sm_89, Ada Lovelace)
- **Driver**: 580.126.09
- **CUDA**: 13.0 (V13.0.48)
- **LLVM**: 19.1.7
- **Clang**: 19.1.7

## 项目结构

```
/Code/llvm_learning/
├── docs/                           # 教程和文档
│   └── LLVM Code Generation(2025).pdf
│
├── examples/                       # 按章节组织的示例代码
│   ├── part1_getting_started/     # Part 1: LLVM 入门
│   ├── part2_middle_end/          # Part 2: 中端优化
│   ├── part3_backend_intro/       # Part 3: 后端入门
│   ├── part4_instruction_selection/ # Part 4: 指令选择
│   └── part5_final_lowering/      # Part 5: 最终优化
│
├── exercises/                      # 练习题
├── notes/                          # 学习笔记
├── scripts/                        # 辅助脚本
│
├── test.cu                         # 测试 CUDA 程序
├── test_e2e.ll                     # LLVM IR (文本)
├── test_e2e.bc                     # LLVM IR (二进制)
├── test_e2e.ptx                    # PTX 汇编
└── test_e2e.cubin                  # GPU 机器码
```

## 编译链命令

### 完整编译流程
```bash
# Step 1: .cu -> .ll (LLVM IR 文本)
clang -x cuda --cuda-gpu-arch=sm_89 --cuda-device-only -S -emit-llvm test.cu -o test.ll

# Step 2: .ll -> .bc (LLVM IR 二进制)
llvm-as test.ll -o test.bc

# Step 3: .bc -> .ptx (PTX 汇编)
llc test.bc -march=nvptx64 -mcpu=sm_89 -filetype=asm -o test.ptx
# Step 2+3: .ll -> .ptx (PTX 汇编)
llc test.ll -march=nvptx64 -mcpu=sm_89 -o test.ptx

# Step 4: .ptx -> .cubin (GPU 机器码)
ptxas test.ptx -arch=sm_89 -o test.cubin
```

### 验证和调试
```bash
# 查看 SASS 反汇编
cuobjdump -sass test.cubin

# 查看 PTX 详细信息
nvdisasm test.cubin

# 运行优化 Pass
opt -O2 test.ll -o test_opt.ll
```

## 学习路径

### Phase 1: 基础入门 (Week 1-2)
- [ ] Chapter 1: Building LLVM and Directory Structure
- [ ] Chapter 3: Compiler Basics and LLVM APIs
- [ ] Chapter 7: Understanding LLVM IR ⭐⭐⭐

### Phase 2: 动手优化 (Week 3-4)
- [ ] Chapter 4: Writing Your First Optimization ⭐⭐⭐
- [ ] Chapter 5: Dealing with Pass Managers
- [ ] Chapter 10: Hands-On Debugging LLVM IR Passes

### Phase 3: 深入后端 (Week 5-8)
- [ ] Chapter 6: TableGen
- [ ] Chapter 11: Getting Started with the Backend ⭐⭐⭐
- [ ] Chapter 12: Getting Started with Machine Code Layer

### Phase 4: 指令选择 (Week 9-14)
- [ ] Chapters 14-17: Instruction Selection (4 chapters)

### Phase 5: 最终优化 (Week 15-20)
- [ ] Chapter 18: Instruction Scheduling
- [ ] Chapter 19: Register Allocation
- [ ] Chapter 20: Stack Layout Lowering
- [ ] Chapter 21: Assembler

## LLVM 源码

LLVM 19.1.7 源码位于: `/Code/llvm-source/llvm-project/`

重要目录:
- `llvm/lib/Target/NVPTX/` - NVIDIA PTX 后端实现
- `llvm/include/llvm/IR/` - LLVM IR 定义
- `llvm/lib/Passes/` - 优化 Pass 实现
- `llvm/lib/CodeGen/` - 代码生成核心

## 参考资源

- 书籍: LLVM Code Generation (2025) by Quentin Colombet
- 官方文档: https://llvm.org/docs/
- NVPTX 后端: https://llvm.org/docs/NVPTXUsage.html
