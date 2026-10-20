# Chapter 14: Getting Started with Instruction Selection

## 概述

指令选择（Instruction Selection, ISel）是后端的核心阶段，负责将 LLVM IR 降级为 Machine IR：
- 三种框架：FastISel、SDISel、GlobalISel
- 三个阶段：IR Building → Legalization → Selection
- 关键数据结构：SelectionDAG（SDISel）、Generic Machine IR（GlobalISel）

## 指令选择框架对比

| 特性 | FastISel | SDISel | GlobalISel |
|------|----------|--------|------------|
| **编译速度** | 最快 | 较慢（~20% 编译时间） | 中等 |
| **代码质量** | 一般 | 最好 | 好 |
| **通用性** | 有限（需 fallback） | 最好 | 好 |
| **IR 表示** | LLVM IR | SelectionDAG | Generic Machine IR |
| **可测试性** | 差 | 差 | 好（模块化） |
| **架构** | 单一 Pass | 单一 Pass | 多个 MachineFunctionPass |
| **适用场景** | JIT 快速编译 | 生产环境默认 | 新项目推荐 |

## 指令选择三阶段

```
┌─────────────────────────────────────────────────────────────┐
│  1. IR Building (IR 构建)                                    │
│     LLVM IR → SelectionDAG / Generic Machine IR              │
│     引入 ABI 信息（调用约定、参数传递）                        │
├─────────────────────────────────────────────────────────────┤
│  2. Legalization (合法化)                                    │
│     将 IR 降级为目标支持的类型和操作                           │
│     - Type Legalization: 类型合法化                          │
│     - Operation Legalization: 操作合法化                     │
├─────────────────────────────────────────────────────────────┤
│  3. Selection (选择)                                         │
│     将 IR 节点匹配为目标指令                                  │
│     SelectionDAG / Generic MIR → Target Machine IR           │
└─────────────────────────────────────────────────────────────┘
```

## SDISel (SelectionDAG ISel)

### 核心概念

**SelectionDAG**：有向无环图，表示计算流程

```
SDNode: 图中的节点（操作）
SDValue: 节点的输出值（SDNode + 结果索引）
```

### 类层次

```cpp
// 目标相关实现
class XXXDAGToDAGISel : public SelectionDAGISel {
  void Select(SDNode *N) override;  // 核心选择方法
#include "XXXGenDAGISel.inc"       // TableGen 生成
};

// Legacy PM 包装
class XXXDAGToDAGISelLegacy : public SelectionDAGISelLegacy {
  XXXDAGToDAGISelLegacy(TargetMachine &TM)
    : SelectionDAGISelLegacy(ID, std::make_unique<XXXDAGToDAGISel>(TM)) {}
};
```

### TableGen 集成

```cmake
# CMakeLists.txt
tablegen(LLVM XXXGenDAGISel.inc -gen-dag-isel)
```

## GlobalISel

### 核心概念

**Generic Machine IR**：使用通用操作码的 Machine IR

```
G_ADD, G_SUB, G_MUL, G_LOAD, G_STORE, ...
```

### 类层次

```cpp
// 核心 Pass
class Legalizer : public MachineFunctionPass { ... };
class RegBankSelect : public MachineFunctionPass { ... };
class InstructionSelect : public MachineFunctionPass { ... };

// 目标相关实现
class XXXLegalizerInfo : public LegalizerInfo { ... };
class XXXRegisterBankInfo : public RegisterBankInfo { ... };
```

### 类型系统

```cpp
// LowLevelType (LLT)
LLT::scalar(32)        // 32位标量
LLT::pointer(AS, 64)   // 64位指针，地址空间AS
LLT::vector(4, 32)     // 4x32位向量
```

## FastISel

### 特点

- 快速但不完整
- 无法处理的操作 fallback 到 SDISel
- 适用于 JIT 场景

### 集成

```cpp
class XXXFastISel : public FastISel {
  bool fastSelectInstruction(const Instruction *I) override;
#include "XXXGenFastISel.inc"
};

// 在 TargetLowering 中创建
FastISel *createFastISel(FunctionLoweringInfo &FuncInfo,
                         const TargetLibraryInfo *LibInfo) const override {
  return new XXXFastISel(FuncInfo, LibInfo);
}
```

## 关键 API

### TargetLowering

```cpp
class XXXTargetLowering : public TargetLowering {
  // 合法化操作
  bool isOperationLegal(unsigned Opcode, EVT VT) override;
  
  // 类型转换
  EVT getScalarShiftAmountType(const DataLayout &DL, EVT VT) const override;
  
  // 地址模式
  bool isLegalAddressingMode(const DataLayout &DL, const AddrMode &AM,
                            Type *Ty, unsigned AS) const override;
};
```

### TargetInstrInfo

```cpp
class XXXInstrInfo : public XXXGenInstrInfo {
  // 指令折叠
  bool isFoldableCopy(const MachineInstr &MI) const;
  
  // 寄存器类
  const TargetRegisterClass *getRegClass(unsigned RCID) const;
};
```

### TargetRegisterInfo

```cpp
class XXXRegisterInfo : public XXXGenRegisterInfo {
  // 寄存器分配
  const MCPhysReg *getCalleeSavedRegs(const MachineFunction *MF) const override;
  
  // 帧指针
  bool hasBasePointer(const MachineFunction &MF) const;
};
```

## 实践观察

### 实验 1：NVPTX 指令选择

**LLVM IR**:
```llvm
%mul = mul i32 %a, %b
%sum = add i32 %mul, %c
```

**PTX 输出** (mad.lo.s32 融合):
```ptx
mad.lo.s32 %r4, %r1, %r2, %r3;
```

**观察**：mul + add 被融合为单个 mad (multiply-add) 指令。

### 实验 2：x86_64 指令选择

**LLVM IR**:
```llvm
%sum = add i32 %a, %b
```

**x86_64 汇编**:
```asm
leal (%rdi,%rsi), %eax
```

**观察**：add 被选择为 lea (load-effective-address) 指令，利用地址计算单元。

### 实验 3：MIR 中的指令选择

**指令选择后 (finalize-isel)**:
```mir
body: |
  bb.0:
    %0:int32regs = LD_i32_avar 0, 4, 1, 0, 32, &add_param_0
    %1:int32regs = LD_i32_avar 0, 4, 1, 0, 32, &add_param_1
    %2:int32regs = ADDi32rr killed %0, killed %1
    StoreRetvalI32 killed %2, 0
    Return
```

**观察**：
- 虚拟寄存器 `%0`, `%1`, `%2` 已分配寄存器类 `int32regs`
- 指令已选择为目标特定：`LD_i32_avar`, `ADDi32rr`, `StoreRetvalI32`
- `killed` 标记表示最后一次使用

## 连接 CodeGen Pipeline

### AsmPrinter

```cpp
class XXXAsmPrinter : public AsmPrinter {
  void emitInstruction(const MachineInstr *MI) override {
    MCInst TmpInst;
    MachineInstrToMCInst(*MI, TmpInst);
    OutStreamer->emitInstruction(TmpInst, getSubtargetInfo());
  }
};
```

### TargetPassConfig

```cpp
class XXXPassConfig : public TargetPassConfig {
  // SDISel
  bool addInstSelector() override {
    addPass(createXXXISelPass(*getTM(), getOptLevel()));
    return false;
  }
  
  // GlobalISel
  bool addLegalizeMachineIR() override {
    addPass(new Legalizer());
    return false;
  }
  bool addRegBankSelect() override {
    addPass(new RegBankSelect());
    return false;
  }
  bool addGlobalInstructionSelect() override {
    addPass(new InstructionSelect(getOptLevel()));
    return false;
  }
};
```

## 选择哪个框架？

| 场景 | 推荐 |
|------|------|
| 新项目 | GlobalISel |
| 需要最佳代码质量 | SDISel |
| JIT 快速编译 | FastISel + SDISel fallback |
| 已有 SDISel 后端 | 保持 SDISel，逐步迁移 GlobalISel |

## 关键收获

1. **三种框架各有侧重**：FastISel（快）、SDISel（好）、GlobalISel（新）
2. **指令选择三阶段**：IR Building → Legalization → Selection
3. **SelectionDAG 是 SDISel 核心**：SDNode + SDValue 构成 DAG
4. **GlobalISel 使用 Generic MIR**：G_ADD, G_MUL 等通用操作码
5. **TableGen 生成选择代码**：-gen-dag-isel, -gen-fast-isel, -gen-global-isel
6. **融合指令是优化关键**：mul+add → mad, lea 替代 add
7. **AsmPrinter 连接 MC 层**：MachineInstr → MCInst → 汇编
8. **TargetPassConfig 注入 Pass**：addInstSelector, addLegalizeMachineIR 等

## 待探索

- [ ] 实现自定义 SelectionDAG 节点选择
- [ ] 观察 Legalization 阶段的类型转换
- [ ] 使用 GlobalISel 的模块化架构
