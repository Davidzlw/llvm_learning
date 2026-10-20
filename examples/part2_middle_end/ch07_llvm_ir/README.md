# Chapter 7: Understanding LLVM IR

## 学习目标

完成本章后，你将能够：
- 理解 LLVM IR 的设计目的和必要性
- 掌握 LLVM IR 文本语法（类型、指令、函数、基本块）
- 区分单值类型、label 类型、聚合类型
- 理解 intrinsic 函数和 target-specific 元素
- 区分文本 IR (.ll) 和 bitcode (.bc) 格式

---

## 7.1 为什么需要 IR？

IR（中间表示）是编译器内部用于执行变换的数据结构。好的 IR 需要满足：
- **可分析**：能提取程序语义信息
- **可变换**：能安全地修改程序
- **可生成**：能从前端生成，能向下翻译为目标代码

### IR 的三种形式

| 形式 | 文件后缀 | 用途 |
|------|---------|------|
| 文本 IR | `.ll` | 人类可读，开发者调试 |
| 二进制 IR (bitcode) | `.bc` | 紧凑、向后兼容 |
| 内存表示 | — | C++ 类层次结构 |

> **关键区别**：bitcode 保证向后兼容，文本 IR 不保证。

---

## 7.2 LLVM IR 结构层次

```
Module
  ├── target datalayout / target triple
  ├── 全局变量 (@global_counter)
  ├── 类型定义 (%struct.Point = type { i32, i32 })
  └── Function
        ├── 参数 (i32 %arg)
        ├── 属性 (noinline, nounwind, ...)
        └── BasicBlock
              ├── 指令 (add, load, store, br, ...)
              └── terminator (ret, br, switch, ...)
```

---

## 7.3 类型系统

### 类型分类

| 类别 | 类型 | 语法 | C++ 类 |
|------|------|------|--------|
| **单值类型** | 整数 | `i1`, `i8`, `i32`, `i64` | `IntegerType` |
| | 浮点 | `half`, `float`, `double` | `FPType` |
| | 指针 | `ptr` | `PointerType` |
| | 向量 | `<4 x i32>` | `VectorType` |
| **Label 类型** | 基本块地址 | `label %bb` | — |
| **聚合类型** | 结构体 | `{ i32, ptr }` | `StructType` |
| | 数组 | `[4 x i32]` | `ArrayType` |
| **其他** | void | `void` | — |
| | 函数 | `i32 (i32, i32)` | `FunctionType` |

### 特殊值

- `undef` — 未定义值（不关心内容）
- `poison` — 毒值（使用会导致未定义行为）
- `zeroinitializer` — 零初始化

---

## 7.4 指令

### 通用语法

```llvm
%result = opcode type %operand1, %operand2
```

### 常见指令分类

| 类别 | 指令 | 说明 |
|------|------|------|
| **算术** | `add`, `sub`, `mul`, `udiv`, `sdiv` | 整数运算 |
| **位运算** | `shl`, `lshr`, `ashr`, `and`, `or`, `xor` | 移位和逻辑 |
| **内存** | `alloca`, `load`, `store`, `getelementptr` | 内存操作 |
| **比较** | `icmp`, `fcmp` | 整数/浮点比较 |
| **转换** | `zext`, `sext`, `trunc`, `bitcast` | 类型转换 |
| **控制流** | `br`, `switch`, `ret`, `call` | 分支和调用 |
| **SSA** | `phi`, `select` | 合并和条件选择 |

### NSW/NUW 标志

```llvm
%r = add nsw i32 %a, %b   ; No Signed Wrap（无有符号溢出）
%r = mul nuw i32 %a, %b   ; No Unsigned Wrap（无无符号溢出）
```

### phi 指令

phi 是 SSA 形式的核心——在控制流合并点选择来自不同前驱的值：

```llvm
%.0 = phi i32 [ %4, %bb_then ], [ %6, %bb_else ]
```

---

## 7.5 标识符与命名

### 隐式编号的陷阱

未命名的基本块和值会自动分配递增编号。手动编辑 IR 时极易冲突：

```llvm
; 错误：%2 与隐式基本块编号冲突
define i32 @add(i32 %0, i32 %1) {
  %2 = add i32 %0, %1   ; error: expected '%3' or greater
  ret i32 %2
}

; 修复：给基本块命名
define i32 @add(i32 %0, i32 %1) {
bb:
  %2 = add i32 %0, %1
  ret i32 %2
}
```

### 使用 instnamer

```bash
cat input.ll | sed 's#optnone##g' | opt -S -passes=instnamer -o -
```

---

## 7.6 Target-Specific 元素

### Triple

```llvm
target triple = "x86_64-pc-linux-gnu"   ; x86 主机
target triple = "nvptx64-nvidia-cuda"    ; NVIDIA GPU
```

### Intrinsic 函数

| 类型 | 命名 | 示例 |
|------|------|------|
| 通用 | `llvm.<描述>` | `llvm.vector.reduce.add.v4i32` |
| 目标特定 | `llvm.<target>.<描述>` | `llvm.nvvm.read.ptx.sreg.ctaid.x` |

**NVPTX intrinsics**：
```llvm
%blockIdx  = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()  ; blockIdx.x
%blockDim  = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()   ; blockDim.x
%threadIdx = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()    ; threadIdx.x
```

### LLVM IR 不是可移植格式

triple、data layout、intrinsics、ABI 都是 target-specific。

---

## 7.7 实践观察

### mem2reg：从 alloca 到 SSA

```
O0 (alloca 模式):                    mem2reg 后 (SSA):
%3 = alloca i32                      ; (alloca 全部消除)
store i32 %0, ptr %3                 %3 = add nsw i32 %0, %1
%8 = load i32, ptr %3                %4 = mul nsw i32 %3, 2
%10 = add nsw i32 %8, %9             %5 = shl i32 %4, 3
                                     ret i32 %5
```

### O0 vs O2 优化效果

| 函数 | O0 | O2 |
|------|-----|-----|
| basic_arithmetic | add + mul*2 + shl*3 | add + shl*4（代数化简） |
| control_flow | 分支 + phi | select（if-conversion） |
| loop_sum | 循环累加 | 闭式公式（循环消除） |
| array_sum | 循环 + load | 向量化 + llvm.vector.reduce.add |

### bitcode vs 文本 IR

```
文本 IR: 5.1 KB
bitcode: 3.1 KB  (节省 ~40%)
```

---

## 7.8 核心收获

1. **LLVM IR 是编译器的核心数据结构**，连接前端和后端
2. **四种结构层次**：Module → Function → BasicBlock → Instruction
3. **SSA 形式**：每个值只被定义一次，phi 指令处理控制流合并
4. **mem2reg 是关键 Pass**：将 alloca 模式提升为 SSA 寄存器模式
5. **intrinsic 函数**是前端与后端的桥梁，分为通用和目标特定两类
6. **LLVM IR 不是可移植格式**——triple、data layout、ABI 都是 target-specific
7. **bitcode 向后兼容，文本 IR 不保证**
8. **隐式编号是陷阱**——手动编辑 IR 前先用 instnamer

---

## 7.9 参考资源

- LLVM 语言参考: https://llvm.org/docs/LangRef.html
- GEP 指令详解: https://llvm.org/docs/GetElementPtr.html
- 下一章: Chapter 8 - Survey of the Existing Passes
