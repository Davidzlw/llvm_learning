# Chapter 11: Getting Started with the Backend

## 概述

本章深入介绍 Machine IR（机器中间表示），这是后端编译的核心数据结构：
- Machine IR 的文本表示（.mir 文件）
- MachineInstr 和 MachineOperand API
- MC 层（Machine Code layer）概念
- 寄存器、指令、基本块的后端表示
- TableGen 描述后端（寄存器类、指令定义）

## Machine IR vs LLVM IR

| 特性 | LLVM IR | Machine IR |
|------|---------|------------|
| SSA 形式 | 强制 SSA | SSA + non-SSA |
| 寄存器 | 虚拟寄存器（无限） | 虚拟 + 物理寄存器 |
| 类型系统 | 丰富（i32, float, ptr...） | 仅位宽（b32, b64...） |
| 指令 | 目标无关 | 目标相关（真实指令） |
| 文本格式 | .ll | .mir (YAML) |
| 地址空间 | 显式 addrspace | 隐含在指令中 |
| 基本块 | 以 terminator 结束 | 以 terminator 结束 |

## MIR 文件格式

### 结构

```yaml
--- |
  ; LLVM IR 部分（嵌入的原始 IR）
  target datalayout = "..."
  define i32 @add(i32 %a, i32 %b) { ... }
...
---
name:            add           # 函数名
alignment:       1
tracksRegLiveness: true
registers:                     # 虚拟寄存器声明
  - { id: 0, class: int32regs }
  - { id: 1, class: int32regs }
liveins:         []            # 物理寄存器输入
frameInfo:                     # 栈帧信息
  stackSize: 0
  maxAlignment: 1
body:             |            # 指令体
  bb.0 (%ir-block.0):
    %0:int32regs = LD_i32_avar ...
    %1:int32regs = LD_i32_avar ...
    %2:int32regs = ADDi32rr killed %0, killed %1
    StoreRetvalI32 killed %2, 0
    Return
...
```

### 关键字段

| 字段 | 说明 |
|------|------|
| `name` | 函数名 |
| `registers` | 虚拟寄存器列表，含寄存器类 |
| `liveins` | 函数入口时活跃的物理寄存器 |
| `frameInfo` | 栈帧大小、对齐等 |
| `body` | 基本块和指令序列 |
| `tracksRegLiveness` | 是否跟踪寄存器活跃性 |

## MachineInstr 解剖

### 三个组成部分

1. **MachineOperand 数组**：操作数列表
2. **Flags**：fast-math、call frame setup 等标志
3. **MCInstrDesc**：指令描述（不可变），定义操作数约束

### 操作数顺序（由 MCInstrDesc 保证）

```
[显式定义] → [显式使用] → [隐式操作数]
   (defs)      (uses)      (implicit)
```

### 示例（x86_64）

```mir
%2:gr32 = ADD32rr %0:gr32, %1:gr32, implicit-def dead $eflags
```

- `%2:gr32`：显式定义（输出）
- `%0:gr32, %1:gr32`：显式使用（输入）
- `implicit-def dead $eflags`：隐式定义（flags 寄存器）

## MachineOperand 类型

| 类型 | 判断方法 | 获取方法 |
|------|----------|----------|
| 寄存器 | `isReg()` | `getReg()` |
| 立即数 | `isImm()` | `getImm()` |
| 基本块 | `isMBB()` | `getMBB()` |
| 符号 | `isGlobal()` | `getGlobal()` |
| 常量池 | `isCPI()` | `getIndex()` |
| 帧索引 | `isFI()` | `getIndex()` |

### 寄存器操作数

```cpp
MO.isReg()          // 是寄存器？
MO.getReg()         // 获取寄存器编号
MO.isDef()          // 是定义还是使用？
MO.isImplicit()     // 是隐式操作数？
MO.isKill()         // 是最后一次使用（kill）？
MO.isDead()         // 定义后未被使用？
```

## 隐式 vs 显式操作数

**显式操作数**：可以在源码中直接指定的操作数
```mir
%0 = ADD %1, %2    // %0, %1, %2 都是显式
```

**隐式操作数**：硬件或 ABI 约束，不可直接控制
```mir
// x86 比较指令隐式修改 eflags
%eflags = CMP %0, %1    // eflags 是隐式定义

// 调用约定隐式使用特定寄存器
CALL @func, implicit $edi, implicit $esi, implicit-def $eax
```

## 特殊操作数约束

### Tied Operands（绑定操作数）

某些指令的读-写操作必须使用同一物理寄存器：
```mir
// x86 ADD: %dst = ADD %dst, %src
// dst 同时是读和写，必须 tied
%0 = ADD32rr %0(tied-def), %1
```

### Early-clobber（早写约束）

定义在所有使用之前产生，不能与输入共享寄存器：
```mir
%0:gr64 = EARLY_CLOBBER_INST %1, %2
// %0 不能与 %1 或 %2 分配同一物理寄存器
```

## 寄存器类

### NVPTX 寄存器类示例

```yaml
registers:
  - { id: 0, class: int32regs }   # 32位整数寄存器
  - { id: 1, class: int32regs }
  - { id: 2, class: int64regs }   # 64位整数寄存器
```

### x86_64 寄存器类

```yaml
registers:
  - { id: 0, class: gr32 }        # 32位通用寄存器
  - { id: 1, class: gr64 }        # 64位通用寄存器
  - { id: 2, class: fr32 }        # 32位浮点寄存器
```

## 实践观察

### 实验 1：NVPTX Machine IR

```mir
body: |
  bb.0 (%ir-block.0):
    %0:int32regs = LD_i32_avar 0, 4, 1, 0, 32, &add_param_0
    %1:int32regs = LD_i32_avar 0, 4, 1, 0, 32, &add_param_1
    %2:int32regs = ADDi32rr killed %0, killed %1
    StoreRetvalI32 killed %2, 0
    Return
```

**观察**：
- 使用虚拟寄存器 `%0`, `%1`, `%2`
- 寄存器类 `int32regs`
- 指令是 NVPTX 特定的：`LD_i32_avar`, `ADDi32rr`, `StoreRetvalI32`
- `killed` 标记表示最后一次使用

### 实验 2：x86_64 Machine IR

```mir
body: |
  bb.0 (%ir-block.0):
    liveins: $edi, $esi

    %1:gr32 = COPY $esi
    %0:gr32 = COPY $edi
    %2:gr32 = ADD32rr %0, %1, implicit-def dead $eflags
    $eax = COPY %2
    RET 0, $eax
```

**观察**：
- `liveins` 指定入口活跃的物理寄存器（`$edi`, `$esi`）
- `COPY` 在物理和虚拟寄存器间移动数据
- `implicit-def dead $eflags`：隐式定义 flags，标记为 dead
- `$eax = COPY %2`：返回值放入 `$eax`

### 实验 3：最终汇编对比

**NVPTX PTX**:
```ptx
ld.param.u32  %r1, [add_param_0];
ld.param.u32  %r2, [add_param_1];
add.s32       %r3, %r1, %r2;
st.param.b32  [func_retval0+0], %r3;
ret;
```

**x86_64 Assembly**:
```asm
leal (%rdi,%rsi), %eax
retq
```

## TableGen 后端描述

### 寄存器描述

```tablegen
// NVPTX 寄存器类定义
def int32regs : RegisterClass<"NVPTX", [i32], 32, (add IPRED, FPRED, ...)>;
```

### 指令描述

```tablegen
def ADDi32rr : Instruction<
  (outs int32regs:$dst),
  (ins int32regs:$src1, int32regs:$src2),
  "add.s32 \t$dst, $src1, $src2",
  []
>;
```

### 生成命令

```bash
# 生成寄存器信息
llvm-tblgen -gen-register-info NVPTX.td -o NVPTXGenRegisterInfo.inc

# 生成指令信息
llvm-tblgen -gen-instr-info NVPTX.td -o NVPTXGenInstrInfo.inc

# 生成子目标信息
llvm-tblgen -gen-subtarget NVPTX.td -o NVPTXGenSubtargetInfo.inc
```

## MC 层

MC 层是 Machine 层的底层基础，负责汇编/反汇编：

| MC 类 | Machine 类 | 职责 |
|-------|------------|------|
| `MCInst` | `MachineInstr` | 指令实例 |
| `MCOperand` | `MachineOperand` | 操作数 |
| `MCInstrInfo` | `TargetInstrInfo` | 指令信息 |
| `MCRegisterInfo` | `TargetRegisterInfo` | 寄存器信息 |
| `MCInstrDesc` | - | 指令描述（不可变） |

**MCInstrDesc** 定义指令的"契约"：
- 操作数数量和类型
- 编码约束
- 副作用（mayLoad, mayStore, isBarrier 等）

## 工具命令速查

```bash
# 生成 MIR（停止在指令选择后）
llc -stop-after=finalize-isel input.ll -o output.mir

# 从 MIR 继续编译
llc -start-after=finalize-isel input.mir -o output.s

# 运行单个 Pass
llc -run-pass=instruction-select input.ll -o output.mir

# 指定 Pass 范围
llc -start-after=pass1 -stop-after=pass2 input.ll -o output.mir

# 查看 Pass 列表
llc --help | grep "start-after\|stop-after\|run-pass"
```

## 关键收获

1. **Machine IR 是后端的通用表示**：连接 LLVM IR 和最终汇编
2. **MIR 使用 YAML 格式**：包含 LLVM IR + Machine 函数信息
3. **MachineInstr = 操作数数组 + MCInstrDesc 约束**
4. **隐式操作数建模硬件/ABI 约束**：如 x86 eflags、调用约定寄存器
5. **Tied operands 打破 SSA**：读-写操作必须共享物理寄存器
6. **寄存器类定义可用寄存器集合**：int32regs, gr64, fr32 等
7. **MC 层是汇编级抽象**：编码、反汇编、指令描述
8. **TableGen 生成后端骨架**：寄存器、指令、子目标信息

## 待探索

- [ ] 深入理解指令选择（Instruction Selection）过程
- [ ] 观察寄存器分配前后的 MIR 变化
- [ ] 使用 TableGen 定义自定义指令
