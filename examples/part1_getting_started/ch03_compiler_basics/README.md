# Chapter 3: Compiler Basics and How They Map to LLVM APIs

## 学习目标

完成本章后，你将能够：
- ✅ 熟悉编译器常用术语
- ✅ 建立这些概念的心智模型
- ✅ 通过 LLVM API 操作这些概念
- ✅ 编写程序从零构建 LLVM IR 和 Machine IR

---

## 3.1 编译器术语 (Compiler Jargon)

### Target（目标）
**定义**: 程序将运行其上的硬件架构。

- 也用作动词：为目标架构实现/特化功能
- 例如："targeting instruction selection" = 修改指令选择以支持特定目标

**我们的环境**: Target = NVIDIA GeForce RTX 4090 D (sm_89)

### Host（宿主机）
**定义**: 运行编译器的设备。

- Host = Target → 本地编译
- Host ≠ Target → **交叉编译** (cross-compilation)
- 例如：在 x86 桌面上编译 AArch64 手机代码

**我们的环境**: Host = x86_64, Target = nvptx64 → 交叉编译！

### Lowering（降低）
**定义**: 编译过程中，程序逐步降低抽象级别，直到最终成为目标机器的汇编。

```
高级语言 (C/C++/CUDA)
    ↓ lowering
LLVM IR (高级、目标无关)
    ↓ lowering
Machine IR (中级、目标相关)
    ↓ lowering
SASS/汇编 (低级、机器码)
```

**关键理解**: 整个编译过程就是一个不断 lowering 的过程！

### Canonical Form（规范形式）
**定义**: 推荐的表示方式。编译器会尽量将表达式转换为统一形式。

例如：
- `a = b + 2` 和 `a = 2 + b` 语义相同
- 规范形式规则：常量放在二元运算符右侧 → `a = b + 2`
- LLVM 提供 API 来自动 canonicalize IR

### Build Time / Compile Time / Runtime
| 术语 | 含义 | 示例 |
|------|------|------|
| **Build time** | 构建编译器的时间 | Ninja 编译 LLVM 的时间 |
| **Compile time** | 编译器处理文件的时间 | Clang 从源文件生成目标文件的时间 |
| **Runtime** | 最终二进制执行的时间 | 运行 Clang 生成的程序的时间 |

> **记忆**: 编译器的 runtime = 你的应用的 compile time

### Backend 和 Middle-end
```
┌──────────┐   ┌────────────┐   ┌──────────────┐
│ Frontend │ → │ Middle-end │ → │   Backend    │
│ (Clang)  │   │ (目标无关) │   │ (目标相关)   │
└──────────┘   └────────────┘   └──────────────┘
  解析源代码      优化 LLVM IR     生成机器码
  生成 LLVM IR    Pass 管线        指令选择
                                   寄存器分配
                                   指令调度
```

> **注意**: "Backend" 有两种含义：
> 1. 广义：Frontend 之后的所有部分（= Middle-end + 狭义 Backend）
> 2. 狭义：特定目标的代码生成部分（如 x86 backend、NVPTX backend）

### ABI (Application Binary Interface)
**定义**: 描述函数之间如何互相调用的底层规范。

- 定义参数如何传递（寄存器？栈？）
- 定义栈对齐、专用寄存器等
- 一个目标可以有多个 ABI，但一个调用约定 (CC) 只对应一个 ABI
- **重要性**: ABI 是不同编译器产物的"粘合剂"

### Encoding（编码）
**定义**: 描述程序最终以二进制格式组装的方式。

- 哪些 bits 定义哪些操作数
- 内存地址如何表示
- 立即数的大小限制

**示例**: x86 早期只支持 2-address 编码
```c
// C 代码
a = b + c;

// 2-address 编码需要改写为
a = b;      // 先复制
a += c;     // 原地操作
```

---

## 3.2 基本结构 (Basic Structures)

### 层次关系总览

```
Module (模块)
  └── Function (函数)
        └── BasicBlock (基本块)
              └── Instruction (指令)

所有结构通过 CFG (控制流图) 连接
```

### 3.2.1 Module（模块）

**概念**: 当前编译程序的容器 ≈ 输入文件（翻译单元/编译单元）

#### LLVM IR 级别

**类**: `Module` (IR 库)

**创建方式**:
```cpp
// 方式 1: 从头创建
LLVMContext Context;
Module MyModule("MyModule", Context);

// 方式 2: 从文件加载 (.ll 或 .bc)
LLVMContext Context;
SMDiagnostic Err;
std::unique_ptr<Module> MyModule = parseIRFile("MyIRFile", Err, Context);

// 方式 3: 从字符串加载
LLVMContext Context;
SMDiagnostic Err;
std::unique_ptr<Module> MyModule = parseAssemblyString(InputIR, Err, Context);
```

**LLVMContext 的作用**:
- 负责 uniquing（唯一化）信息
- 相同类型和值的常量共享同一底层对象
- 比较常量只需比较地址

**常用 API**:
```cpp
// 遍历所有函数
for (Function &MyFunction : MyModule) {
    // 处理 MyFunction
}

// 获取特定函数
Function *F = MyModule.getFunction("foo");

// 全局变量
GlobalVariable *GV = MyModule.getGlobalVariable("myGlobal");
MyModule.insertGlobalVariable(GV);
```

#### Machine IR 级别
- **没有** Module 的直接概念
- 代码通常一次只处理一个函数
- 通过 `MachineModuleInfo` API 间接访问 Module 信息

---

### 3.2.2 Function（函数）

**概念**: 命名的计算实体，可从多处调用

> LLVM 不区分 function、member function、procedure、lambda 等。对后端来说，一切都是 function。

#### LLVM IR 级别

**类**: `Function` (IR 库)

**关键 API**:
```cpp
// 查询属性
Type *RetTy = F->getReturnType();       // 返回类型
auto Args = F->arg_begin();              // 参数列表开始
auto Attrs = F->getAttributes();         // 属性

// 判断定义 vs 声明
bool isDecl = F->empty();               // true = 声明
bool isDecl2 = F->isDeclaration();      // 同上

// 访问父 Module
Module *M = F->getParent();

// 遍历基本块
for (BasicBlock &BB : *F) {
    // 处理 BB
}
```

#### Machine IR 级别

**类**: `MachineFunction` (CodeGen 库)

- 提供指向对应 LLVM IR Function 的指针
- 暴露底层属性（如是否还有虚拟寄存器）
```cpp
Function &IRFunc = MF.getFunction();  // 获取对应的 IR Function

for (MachineBasicBlock &MBB : MF) {
    // 处理 MBB
}
```

---

### 3.2.3 Basic Block（基本块）

**定义**: 单入口单出口 (SESE) 的代码区域

**关键特征**:
- 连续的指令序列
- 执行到任一指令时，之前所有指令已执行，之后所有指令将执行
- 通常形成**极大** (maximal) 形式

**示例**:
```c
// C 代码                          // 基本块划分
int foo(int a) {                   BB1: b = bar(); c = baz();
  int b = bar();                     (c == a)
  int c = baz();                 BB2: goto END;
  if (c == a)                    IF: b += a * bar();
    goto IF;                     END: return b;
  else
    goto END;
IF:
  b += a * bar();
END:
  return b;
}
```

#### LLVM IR 级别

**类**: `BasicBlock` (IR 库)

**约束**:
1. 必须有且只有一个 **terminator 指令**（在最后）
2. 某些特殊指令（如 PHI）必须在最前面
3. 非空指令列表

**关键 API**:
```cpp
// 遍历指令
for (Instruction &I : BB) { }

// 获取父函数
Function *F = BB.getParent();

// 获取第一个非 PHI 指令
Instruction *First = BB.getFirstNonPHI();

// 获取 terminator
Instruction *Term = BB.getTerminator();

// 安全遍历范围: [getFirstNonPHI(), getTerminator()]
```

#### Machine IR 级别

**类**: `MachineBasicBlock` (CodeGen 库)

**与 LLVM IR 的区别**:
- 可以有 **零个或多个** terminator 指令
- 直接提供前驱/后继遍历 API (`predXXX`, `succXXX`)
- Terminator 可选，可能 fall-through 到下一个基本块

---

### 3.2.4 Instruction（指令）

**定义**: IR 中最小的计算单元

**三个核心要素**:
```
temp1 = a * temp0
  │       │   │
  │       │   └── arguments/uses (操作数)
  │       └────── opcode (操作码: *)
  └────────────── definitions (定义/结果: temp1)
```

**打印格式**: `def0, def1, … = opcode arg0, arg1, …`

#### LLVM IR 级别

**类**: `Instruction` (IR 库)

**关键 API**:
```cpp
// 查询三要素
unsigned Op = I.getOpcode();     // 操作码
Value *Arg = I.getOperand(0);    // 操作数 (参数)
// I 本身就是定义 (Value*)

// 移动指令
I.moveBefore(&OtherInstr);
I.insertBefore(&OtherInstr);

// 获取父基本块
BasicBlock *BB = I.getParent();
```

> **重要**: LLVM IR 中，指令本身就是定义（Value*）。参数是指向定义它们的指令的指针。

#### Machine IR 级别

**类**: `MachineInstr` (CodeGen 库)

**与 LLVM IR 的区别**:
- 更灵活但不那么直观
- 定义和参数都通过 `getOperand(index)` 获取
- 需要解包 `MachineOperand` 来区分定义和参数
- 提供 `defs()` 和 `uses()` 辅助迭代器

---

### 3.2.5 Control Flow Graph（控制流图, CFG）

**定义**: 以图的形式表示函数的执行流程

- **节点 (N)**: 基本块
- **有向边 (E)**: src 可以跳转到 dst
- **入口点**: 函数的入口
- **出口点**: 所有 return 点

#### 重要 CFG 概念

##### Reverse Post-Order (RPO) 遍历
- 保证拓扑序：先遇到定义，后遇到使用
```cpp
// LLVM IR
ReversePostOrderTraversal<Function *> RPOT(&MyFunction);
for (BasicBlock *BB : RPOT) {
    // 按拓扑序处理
}

// Machine IR
ReversePostOrderTraversal<MachineFunction *> RPOT(&MyMachineFunction);
for (MachineBasicBlock *MBB : RPOT) {
    // 按拓扑序处理
}
```

##### Backedge（回边）
- 指向"后方"的控制流边 → 形成循环
- 正式定义：不遵循拓扑序的边
- **重要性**: 识别回边 → 识别循环 → 循环优化

##### Critical Edge（关键边）
- 源有多个后继 **且** 目标有多个前驱的边
- **问题**: 无法单独为该边做优化而不影响其他路径
- **解决**: 拆分关键边（插入新的基本块）

##### Irreducible Graph（不可约图）
- 循环不完美嵌套 → 不可约 CFG
- **风险**: 可能导致分析给出意外结果
- **检测**: `containsIrreducibleCFG` API
- **修复**: `FixIrreduciblePass`（仅 LLVM IR 级别）

---

## 3.3 LLVM IR vs Machine IR 对照表

| 概念 | LLVM IR 类 | Machine IR 类 | 所在库 |
|------|-----------|--------------|--------|
| 模块 | `Module` | 无直接概念 | IR / - |
| 函数 | `Function` | `MachineFunction` | IR / CodeGen |
| 基本块 | `BasicBlock` | `MachineBasicBlock` | IR / CodeGen |
| 指令 | `Instruction` | `MachineInstr` | IR / CodeGen |
| 上下文 | `LLVMContext` | - | IR |

### 关键差异总结

| 特性 | LLVM IR | Machine IR |
|------|---------|------------|
| 抽象级别 | 高（目标无关） | 低（目标相关） |
| 寄存器 | 无限虚拟寄存器 | 物理寄存器 + 虚拟寄存器 |
| 指令 | SSA 形式 | 非 SSA（可重定义） |
| Terminator | 必须有且仅有一个 | 可以零个或多个 |
| 前驱/后继 | 需要额外查询 | 直接 API |
| 类型系统 | 丰富 | 简单或无 |

---

## 3.4 与我们编译链的对应关系

```
test.cu (CUDA 源码)
    │
    │ [clang - CUDA Frontend]
    ↓
test.ll (LLVM IR 文本)          ← Module, Function, BasicBlock, Instruction
    │
    │ [llvm-as]
    ↓
test.bc (LLVM IR 二进制)        ← 同样的结构，二进制编码
    │
    │ [llc -march=nvptx64 -mcpu=sm_89]
    ↓                              现在进入 Machine IR 领域
test.ptx (PTX 汇编)            ← MachineFunction, MachineBasicBlock, MachineInstr
    │
    │ [ptxas -arch=sm_89]
    ↓
test.cubin (GPU 机器码)         ← 最终编码后的二进制
```

---

## 3.5 实践：在 test.ll 中观察这些概念

```bash
cd /Code/llvm_learning

# 查看 Module 级别信息（头部）
head -15 test_e2e.ll
# → target triple, target datalayout, 全局类型定义

# 查看 Function
grep "define" test_e2e.ll
# → @_Z11helloKernelv 就是 Function

# 查看 BasicBlock
grep -n "^" test_e2e.ll | head -30
# → 函数体内的每个标签都是一个基本块的开始

# 查看 Instruction
# → 函数体内的每一行（%x = ...）就是一条指令
```

---

## 3.6 关键 API 头文件位置

```
llvm/include/llvm/IR/
├── Module.h           # Module 类
├── Function.h         # Function 类
├── BasicBlock.h       # BasicBlock 类
├── Instructions.h     # Instruction 类及各种子类
├── IRBuilder.h        # 构建 IR 的辅助类 ⭐
├── LLVMContext.h      # LLVMContext 类
├── DerivedTypes.h     # 派生类型
├── Constants.h        # 常量
└── Value.h            # Value 基类

llvm/include/llvm/CodeGen/
├── MachineFunction.h
├── MachineBasicBlock.h
├── MachineInstr.h
└── MachineOperand.h

llvm/include/llvm/IR/
├── IRReader.h         # parseIRFile
├── AsmParser.h        # parseAssemblyString

llvm/include/llvm/ADT/
└── GenericDomTree.h   # ReversePostOrderTraversal
```

---

## 3.7 本章核心收获

1. **编译器是一个逐步降低抽象级别的过程** (lowering)
2. **LLVM 有两个核心 IR 级别**: LLVM IR（高级）和 Machine IR（低级）
3. **四种基本结构**: Module → Function → BasicBlock → Instruction
4. **每种结构在两个 IR 级别都有对应类**，但行为和约束不同
5. **CFG 是理解程序执行流程的关键**: RPO、Backedge、Critical Edge、Irreducible Graph
6. **LLVMContext 负责 uniquing**: 相同常量共享对象
7. **ABI 是不同编译器产物之间的契约**

---

## 3.8 参考资源

- LLVM Doxygen API: https://llvm.org/doxygen/
- 书籍 GitHub: https://github.com/PacktPublishing/LLVM-Code-Generation
- LLVM IR 文档: https://llvm.org/docs/LangRef.html
- 下一章: Chapter 4 - Writing Your First Optimization
