# Chapter 3 Quiz - Compiler Basics and LLVM APIs

## 选择题

### 1. 在编译器术语中，"lowering" 指的是什么？
A) 降低代码质量以加快编译速度  
B) 将高级抽象逐步转换为更接近目标的低级表示  
C) 减少源代码的行数  
D) 降低程序的内存使用  

<details>
<summary>答案</summary>
B) 将高级抽象逐步转换为更接近目标的低级表示

Lowering 是编译过程的核心概念：程序从高级语言 → LLVM IR → Machine IR → 汇编，每一步都在降低抽象级别。
</details>

---

### 2. 在 LLVM IR 中，一个基本块 (BasicBlock) 必须满足什么条件？
A) 可以有多个 terminator 指令  
B) 必须有且只有一个 terminator 指令  
C) 不需要 terminator 指令  
D) 必须为空  

<details>
<summary>答案</summary>
B) 必须有且只有一个 terminator 指令

LLVM IR 的 BasicBlock 约束：
- 必须有且只有一个 terminator（如 ret, br, switch）
- Terminator 必须在最后
- PHI 节点（如果有）必须在最前面
- 基本块不能为空

注意：MachineBasicBlock 更灵活，可以有零个或多个 terminator。
</details>

---

### 3. LLVMContext 的主要作用是什么？
A) 存储编译选项  
B) 管理目标机器信息  
C) 唯一化 (uniquing) 类型和常量等信息  
D) 控制优化级别  

<details>
<summary>答案</summary>
C) 唯一化 (uniquing) 类型和常量等信息

LLVMContext 确保相同类型和值的常量共享同一底层对象。这样比较两个常量只需比较指针地址。
</details>

---

### 4. 以下关于 LLVM IR 和 Machine IR 的描述，哪个是正确的？
A) Machine IR 比 LLVM IR 抽象级别更高  
B) LLVM IR 是目标相关的，Machine IR 是目标无关的  
C) LLVM IR 使用 SSA 形式，Machine IR 不强制 SSA  
D) 两者没有本质区别  

<details>
<summary>答案</summary>
C) LLVM IR 使用 SSA 形式，Machine IR 不强制 SSA

关键区别：
- LLVM IR: 高级、目标无关、SSA、丰富类型系统
- Machine IR: 低级、目标相关、非强制SSA、引入物理寄存器
</details>

---

### 5. 什么是 Critical Edge（关键边）？
A) 连接入口和出口的边  
B) 源有多个后继且目标有多个前驱的边  
C) 权重最大的边  
D) 最短的边  

<details>
<summary>答案</summary>
B) 源有多个后继且目标有多个前驱的边

关键边的问题：无法单独为该边做优化而不影响其他路径。
解决方法：拆分关键边（插入新的基本块）。
</details>

---

## 填空题

### 6. 编译器的三个主要时间段

- ________ time: 构建编译器本身的时间
- ________ time: 编译器处理源文件的时间
- ________ time: 最终程序执行的时间

<details>
<summary>答案</summary>
- **Build** time: 构建编译器的时间（如 Ninja 编译 LLVM）
- **Compile** time: 编译器处理文件的时间（如 Clang 编译 .cu → .o）
- **Runtime**: 最终程序执行的时间

编译器的 runtime = 用户程序的 compile time
</details>

---

### 7. LLVM 中的四种基本结构（从大到小）

```
________ (模块)
  └── ________ (函数)
        └── ________ (基本块)
              └── ________ (指令)
```

<details>
<summary>答案</summary>
```
Module (模块)
  └── Function (函数)
        └── BasicBlock (基本块)
              └── Instruction (指令)
```
</details>

---

### 8. 指令的三要素

一条指令 `temp1 = a * temp0` 由以下三部分组成：
- ________（结果）: ________
- ________（操作码）: ________
- ________（参数）: ________

<details>
<summary>答案</summary>
- **Definitions**（结果）: temp1
- **Opcode**（操作码）: *
- **Arguments/Uses**（参数）: a 和 temp0
</details>

---

## 实践题

### 9. 在 test.ll 中识别基本结构

阅读 `/Code/llvm_learning/test_e2e.ll`，回答以下问题：

```bash
cat /Code/llvm_learning/test_e2e.ll
```

a) Module 的 target triple 是什么？
b) 有几个 Function 定义？分别是什么？
c) helloKernel 函数有几个 BasicBlock？
d) 列出所有 terminator 指令
e) 找出所有 `llvm.nvvm.*` intrinsic 调用

<details>
<summary>参考答案</summary>

a) `target triple = "nvptx64-nvidia-cuda"`

b) 1 个 Function 定义: `@_Z11helloKernelv`（helloKernel 的 C++ mangled 名称）

c) 1 个 BasicBlock（这个函数很简单，没有分支）

d) `ret void` — 函数末尾的返回指令

e) 三个 NVVM intrinsics:
- `@llvm.nvvm.read.ptx.sreg.ctaid.x()` — 读取 blockIdx.x
- `@llvm.nvvm.read.ptx.sreg.ntid.x()` — 读取 blockDim.x
- `@llvm.nvvm.read.ptx.sreg.tid.x()` — 读取 threadIdx.x
</details>

---

### 10. 绘制 CFG

给定以下 LLVM IR 函数，画出其控制流图 (CFG)：

```llvm
define i32 @foo(i32 %a, i32 %b) {
entry:
  %cmp = icmp eq i32 %a, 0
  br i1 %cmp, label %then, label %else

then:
  %add = add i32 %a, %b
  br label %merge

else:
  %sub = sub i32 %a, %b
  br label %merge

merge:
  %result = phi i32 [%add, %then], [%sub, %else]
  ret i32 %result
}
```

a) 有几个基本块？
b) 有几条边？
c) 入口点和出口点分别是什么？
d) 有没有关键边？

<details>
<summary>参考答案</summary>

a) 4 个基本块: entry, then, else, merge

b) 5 条边:
- entry → then
- entry → else
- then → merge
- else → merge
- （加上隐含的入口边）

c) 
- 入口点: entry
- 出口点: merge（包含 ret 指令）

d) 没有关键边。每条边要么源只有一个后继，要么目标只有一个前驱。

CFG 图:
```
        ┌─────────┐
        │  entry   │
        └────┬─────┘
         ┌───┴───┐
         ▼       ▼
    ┌────────┐ ┌────────┐
    │  then  │ │  else  │
    └───┬────┘ └────┬───┘
        └─────┬─────┘
              ▼
        ┌─────────┐
        │  merge   │
        │ ret %res │
        └─────────┘
```
</details>

---

## 思考题

### 11. 在我们的 CUDA 编译链中，哪些步骤涉及 LLVM IR，哪些涉及 Machine IR？

回顾我们的编译流程：
```
test.cu → test.ll → test.bc → test.ptx → test.cubin
```

请分析每一步对应的 IR 级别。

<details>
<summary>参考答案</summary>

| 步骤 | 工具 | IR 级别 | 说明 |
|------|------|---------|------|
| .cu → .ll | clang | LLVM IR | CUDA 前端生成 LLVM IR |
| .ll → .bc | llvm-as | LLVM IR | 同级别的不同表示形式 |
| .bc → .ptx | llc | LLVM IR → Machine IR | llc 内部先加载为 LLVM IR，经过指令选择等转为 Machine IR，最终输出 PTX |
| .ptx → .cubin | ptxas | Machine IR → 编码 | NVIDIA 专有工具，将 PTX 汇编编码为 cubin |

关键洞察：llc 是 LLVM IR 到 Machine IR 的桥梁！它内部完成了：
1. 加载 LLVM IR
2. 指令选择 (Instruction Selection)
3. 合法化 (Legalization)
4. 寄存器分配 (Register Allocation)
5. 指令调度 (Instruction Scheduling)
6. 输出目标汇编（PTX）
</details>

---

## 评分标准

- 选择题：每题 10 分，共 50 分
- 填空题：每空 5 分，共 30 分（第 6 题 15 分 + 第 7 题 20 分 + 第 8 题 15 分，调整为 30 分）
- 实践题：每题 10 分，共 20 分

**总分：100 分**

**及格线：70 分**

---

## 下一步

完成本章测试后：
- 如果得分 < 70：重新阅读 Chapter 3 笔记，特别是基本结构部分
- 如果得分 >= 70：继续 Chapter 4 - Writing Your First Optimization
- 如果想深入：运行 `explore_ir_structure.sh` 脚本，在真实代码中观察所有概念
