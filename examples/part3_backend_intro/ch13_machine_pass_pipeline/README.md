# Chapter 13: The Machine Pass Pipeline

## 概述

Machine Pass Pipeline 是后端的编译流水线，将 Machine IR 从高级表示逐步降级为最终汇编：
- SSA 虚拟寄存器 → non-SSA 虚拟寄存器 → 物理寄存器
- 通过 TargetPassConfig 注入自定义 Pass
- 复用通用 Machine Pass 优化

## 流水线阶段

```
┌─────────────────────────────────────────────────────────────┐
│  LLVM IR 输入                                                │
├─────────────────────────────────────────────────────────────┤
│  Pre-ISel (指令选择前)                                       │
│  - Pre-ISel Intrinsic Lowering                              │
│  - Target-specific lowering (nvptx-lower-args, etc.)        │
│  - CodeGenPrepare (地址模式优化)                             │
├─────────────────────────────────────────────────────────────┤
│  Instruction Selection (指令选择)                            │
│  - ISel (SelectionDAG → MachineInstr)                       │
│  - Finalize ISel                                            │
├─────────────────────────────────────────────────────────────┤
│  Post-ISel Pre-RA (指令选择后, 寄存器分配前)                 │
│  - Early Tail Duplication                                   │
│  - Optimize Phis                                            │
│  - Machine CSE                                              │
│  - Machine Sink                                             │
│  - Peephole Optimizer                                       │
├─────────────────────────────────────────────────────────────┤
│  Register Allocation (寄存器分配)                            │
│  - Register Coalescer                                       │
│  - Machine Scheduler                                        │
│  - Stack Slot Coloring                                      │
├─────────────────────────────────────────────────────────────┤
│  Post-RA (寄存器分配后)                                      │
│  - Post-RA Pseudos                                          │
│  - Branch Folder                                            │
│  - Block Placement                                          │
│  - Stack Frame Layout                                       │
├─────────────────────────────────────────────────────────────┤
│  MC Layer (机器码层)                                         │
│  - MCInstPrinter → 汇编文本                                 │
│  - MCCodeEmitter → 字节编码                                 │
└─────────────────────────────────────────────────────────────┘
```

## TargetPassConfig 注入点

```cpp
class XXXPassConfig : public TargetPassConfig {
  // 在指令选择前注入
  void addPreISel() override {
    addPass(createXXXPreISelPass());
  }
  
  // 在指令选择后、寄存器分配前注入
  void addPreRegAlloc() override {
    addPass(createXXXPreRAPass());
  }
  
  // 在寄存器分配后注入
  void addPreSched2() override {
    addPass(createXXXPostRAPass());
  }
  
  // 在最终输出前注入
  void addPreEmitPass() override {
    addPass(createXXXFinalPass());
  }
};
```

### 可重载的注入方法

| 方法 | 注入时机 |
|------|----------|
| `addPreISel()` | 指令选择前 |
| `addInstSelector()` | 指令选择阶段 |
| `addPreRegAlloc()` | 寄存器分配前 |
| `addPostRegAlloc()` | 寄存器分配后 |
| `addPreSched2()` | 第二次调度前 |
| `addPreEmitPass()` | 最终输出前 |

## IR 属性变化

| 阶段 | SSA | 寄存器类型 | 指令类型 |
|------|-----|------------|----------|
| LLVM IR 输入 | 强制 SSA | 虚拟 | 目标无关 |
| Post-ISel | SSA | 虚拟 | 目标相关 |
| Post-RA | non-SSA | 物理 | 目标相关 |
| MC 输出 | - | 物理 | 编码完成 |

## 通用 Machine Pass

### 重要 Pass

| Pass | 功能 | 依赖 |
|------|------|------|
| `CodeGenPrepare` | 地址模式优化 | TargetLowering::isLegalAddressingMode |
| `PeepholeOptimizer` | 窥孔优化 | TargetInstrInfo::isBitcast 等 |
| `MachineCombiner` | 指令模式替换 | TargetInstrInfo::getMachineCombinerPatterns |
| `MachineSink` | 指令下沉 | TargetInstrInfo::shouldSink, isSafeToSink |
| `MachineCSE` | 公共子表达式消除 | - |
| `BranchFolder` | 分支优化 | - |

### 发现 Pass 依赖

查看 Pass 源码中的 `getRequiredProperties()` 方法，了解该 Pass 需要的 IR 属性：

```cpp
// 示例：某 Pass 要求 non-SSA 形式
MachineFunctionProperties getRequiredProperties() const override {
  return MachineFunctionProperties().set(
    MachineFunctionProperties::Property::IsSSA);
}
```

## 实践观察

### 实验 1：NVPTX CodeGen Pipeline

```
Pass Arguments:
  -targetlibinfo -targetpassconfig -machinemoduleinfo
  -pre-isel-intrinsic-lowering
  -nvptx-lower-args -sroa -nvptx-lower-alloca
  -infer-address-spaces -nvptx-atomic-lower
  -codegenprepare
  -nvptx-isel -finalize-isel
  -early-tailduplication -opt-phis -machine-cse -peephole-opt
  -register-coalescer -machine-scheduler -stack-slot-coloring
  -nvptx-peephole -branch-folder -postrapseudos
  -block-placement -stack-frame-layout
```

### 实验 2：Pass 分类统计

| 阶段 | Pass 数量 | 典型 Pass |
|------|-----------|-----------|
| Pre-ISel | ~30 | nvptx-lower-args, codegenprepare |
| ISel | 2 | nvptx-isel, finalize-isel |
| Post-ISel Pre-RA | ~15 | machine-cse, peephole-opt, machine-sink |
| RA | ~5 | register-coalescer, machine-scheduler |
| Post-RA | ~15 | nvptx-peephole, branch-folder |

### 实验 3：TargetPassConfig 注入点

```
LLVM IR
  ↓
[addPreISel] ← 注入点 1
  ↓
[addInstSelector] ← 注入点 2 (ISel)
  ↓
[addPreRegAlloc] ← 注入点 3
  ↓
[Register Allocator]
  ↓
[addPostRegAlloc] ← 注入点 4
  ↓
[addPreSched2] ← 注入点 5
  ↓
[addPreEmitPass] ← 注入点 6
  ↓
MC Layer
```

## 关键收获

1. **Machine Pipeline 分 5 大阶段**：Pre-ISel → ISel → Post-ISel Pre-RA → RA → Post-RA
2. **IR 从 SSA 降级到 non-SSA**：寄存器分配是关键转折点
3. **TargetPassConfig 提供 6+ 注入点**：不要重写 addMachinePasses()
4. **通用 Pass 依赖 Target 信息**：TargetLowering, TargetInstrInfo, TargetRegisterInfo
5. **CodeGenPrepare 优化地址模式**：通过 isLegalAddressingMode 控制
6. **PeepholeOptimizer 做目标无关优化**：通过 isBitcast 等属性控制
7. **MachineCombiner 做目标相关优化**：通过 getMachineCombinerPatterns 控制
8. **查看 getRequiredProperties() 了解 Pass 约束**：确定何时可以运行

## 待探索

- [ ] 实现自定义 TargetPassConfig 注入 Pass
- [ ] 观察寄存器分配前后的 MIR 变化
- [ ] 使用 MachineCombiner 实现目标相关优化
