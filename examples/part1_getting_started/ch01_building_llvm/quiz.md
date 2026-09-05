# Chapter 1 Quiz - Building LLVM and Directory Structure

## 选择题

### 1. LLVM 最初代表什么？
A) Low-Level Virtual Machine  
B) Low-Level Variable Management  
C) Large-scale Virtual Machine  
D) Lightweight Virtual Machine  

<details>
<summary>答案</summary>
A) Low-Level Virtual Machine

虽然现在 LLVM 已经远不止是一个虚拟机，但这个名字保留了下来。现在人们直接使用 "LLVM" 作为名称。
</details>

---

### 2. 以下哪个工具用于生成构建系统？
A) Ninja  
B) CMake  
C) Git  
D) Python  

<details>
<summary>答案</summary>
B) CMake

CMake 生成构建系统（例如为 Ninja 或 Make），然后 Ninja/Make 驱动实际的构建过程。
</details>

---

### 3. LLVM IR 的三种形式是什么？
A) 源代码、汇编、机器码  
B) 文本 (.ll)、二进制 (.bc)、内存表示  
C) 高级、中级、低级  
D) C++、C、汇编  

<details>
<summary>答案</summary>
B) 文本 (.ll)、二进制 (.bc)、内存表示

- 文本形式 (.ll)：人类可读的 IR
- 二进制形式 (.bc)：位码，更紧凑
- 内存形式：通过 API 操作的对象
</details>

---

### 4. NVPTX 后端位于哪个目录？
A) llvm/lib/Backend/NVPTX/  
B) llvm/lib/Target/NVPTX/  
C) llvm/lib/CodeGen/NVPTX/  
D) llvm/backends/NVPTX/  

<details>
<summary>答案</summary>
B) llvm/lib/Target/NVPTX/

所有目标后端都位于 llvm/lib/Target/ 目录下，每个后端有自己的子目录。
</details>

---

### 5. 以下哪个工具用于优化 LLVM IR？
A) llc  
B) clang  
C) opt  
D) llvm-as  

<details>
<summary>答案</summary>
C) opt

- opt：LLVM IR 优化器
- llc：后端代码生成器
- clang：C/C++/CUDA 编译器前端
- llvm-as：LLVM IR 汇编器（.ll -> .bc）
</details>

---

## 填空题

### 6. LLVM 项目的三个主要组件是：
1. ________ - 解析源代码生成 LLVM IR
2. ________ - 优化 LLVM IR
3. ________ - 将 LLVM IR 转换为机器码

<details>
<summary>答案</summary>
1. 前端 (Frontend) - 例如 Clang
2. 中端 (Middle-end) - Pass 管线
3. 后端 (Backend) - 指令选择、寄存器分配等
</details>

---

### 7. 在 LLVM 目录结构中：
- `llvm/include/llvm/IR/` 包含 ________
- `llvm/lib/Passes/` 包含 ________
- `llvm/lib/Target/NVPTX/` 包含 ________

<details>
<summary>答案</summary>
- `llvm/include/llvm/IR/`：LLVM IR 的公共头文件定义
- `llvm/lib/Passes/`：优化 Pass 的实现
- `llvm/lib/Target/NVPTX/`：NVIDIA PTX 后端的实现
</details>

---

## 实践题

### 8. 使用命令行工具探索 LLVM 源码

完成以下任务：

```bash
# 1. 进入 LLVM 源码目录
cd /Code/llvm-source/llvm-project

# 2. 列出所有目标后端
ls llvm/lib/Target/

# 3. 查找 NVPTX 后端的所有 .td 文件（TableGen 文件）
find llvm/lib/Target/NVPTX -name "*.td"

# 4. 查看 LLVM IR 头文件
ls llvm/include/llvm/IR/
```

将你的发现记录在笔记中。

<details>
<summary>参考答案</summary>

```bash
# 2. 目标后端包括：AArch64, AMDGPU, ARM, AVR, BPF, Hexagon, 
#    Lanai, LoongArch, Mips, MSP430, NVPTX, PowerPC, RISCV,
#    Sparc, SystemZ, VE, WebAssembly, X86, XCore 等

# 3. NVPTX 的 TableGen 文件：
#    NVPTX.td - 主定义文件
#    NVPTXInstrInfo.td - 指令定义
#    NVPTXRegisterInfo.td - 寄存器定义
#    NVPTXSchedule.td - 调度模型
#    等等

# 4. LLVM IR 头文件包括：
#    IRBuilder.h, Instructions.h, Intrinsics.h,
#    Module.h, Function.h, BasicBlock.h, etc.
```
</details>

---

### 9. 编译链实践

使用我们已有的文件完成以下任务：

```bash
cd /Code/cuda_test

# 1. 查看 test.ll 的前 30 行
head -30 test_e2e.ll

# 2. 使用 opt 运行 -instcombine pass
opt -instcombine test_e2e.ll -o test_combined.ll

# 3. 比较原始和优化后的 IR
diff test_e2e.ll test_combined.ll

# 4. 使用 llc 生成不同优化级别的 PTX
llc test_e2e.bc -march=nvptx64 -mcpu=sm_89 -O0 -o test_O0.ptx
llc test_e2e.bc -march=nvptx64 -mcpu=sm_89 -O3 -o test_O3.ptx

# 5. 比较 PTX 文件大小
ls -lh test_O*.ptx
```

记录你的观察结果。

---

## 思考题

### 10. 为什么 LLVM 使用多种中间表示（IR）？

提示：考虑以下方面：
- 可移植性
- 优化便利性
- 前后端解耦
- 不同抽象层次的需求

<details>
<summary>参考答案</summary>

LLVM 使用多种 IR 的原因：

1. **LLVM IR**（高级）：
   - 与目标无关，便于跨平台优化
   - SSA 形式，便于分析和变换
   - 类型丰富，支持高级语言特性

2. **Machine IR**（中级）：
   - 引入目标特定概念（寄存器、指令）
   - 但仍保持一定抽象，便于机器级优化
   - 寄存器分配、指令调度在此层进行

3. **Machine Code (MC)**（低级）：
   - 接近最终机器码
   - 处理指令编码、重定位等
   - 生成最终目标文件

这种分层设计使得：
- 前端可以专注于语言特性
- 中端可以进行目标无关优化
- 后端可以专注于目标特定优化
- 各层可以独立发展和测试
</details>

---

## 评分标准

- 选择题：每题 10 分，共 50 分
- 填空题：每空 5 分，共 30 分
- 实践题：每题 10 分，共 20 分

**总分：100 分**

**及格线：70 分**

---

## 下一步

完成本章测试后：
- 如果得分 < 70：重新阅读 Chapter 1 内容
- 如果得分 >= 70：继续 Chapter 3: Compiler Basics and LLVM APIs
- 如果想深入：探索 LLVM 源码中的 NVPTX 后端实现
