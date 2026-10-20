# Chapter 9: Introducing Target-Specific Constructs

## 概述

本章讲解如何将 target-specific 信息连接到 LLVM 中间层（middle-end），使通用优化 Pass 能获取目标硬件的约束信息。核心概念：
- 添加新 target 到 LLVM/Clang 基础设施
- 创建 intrinsic（目标特定内建函数）
- 实现 TargetTransformInfo 控制优化行为
- 注入自定义 Pass 到默认流水线
- MC 层骨架搭建

## 关键概念

### 1. Target 架构层次

```
┌─────────────────────────────────────────────┐
│  Clang Frontend                              │
│  TargetInfo → data layout, builtins, attrs  │
├─────────────────────────────────────────────┤
│  LLVM Middle-end (Optimization)              │
│  TargetSubtargetInfo → TargetLowering        │
│  TargetTransformInfo → cost model            │
│  PassBuilder callbacks                       │
├─────────────────────────────────────────────┤
│  LLVM Backend (Code Generation)              │
│  TargetPassConfig → inject custom passes     │
│  SelectionDAG → instruction selection        │
├─────────────────────────────────────────────┤
│  MC Layer (Machine Code)                     │
│  MCAsmInfo, MCSubtargetInfo, MCInstrInfo,    │
│  MCRegisterInfo                              │
└─────────────────────────────────────────────┘
```

### 2. 添加新 Target 的步骤

| 步骤 | 文件/目录 | 说明 |
|------|-----------|------|
| 1 | `llvm/lib/Target/XXX/` | 创建后端目录 |
| 2 | `CMakeLists.txt` | 注册到构建系统 |
| 3 | `XXXTargetMachine.h/cpp` | 实现 TargetMachine 子类 |
| 4 | `XXXSubtarget.h/cpp` | 实现 SubtargetInfo |
| 5 | `XXXISelLowering.h/cpp` | 实现 TargetLowering |
| 6 | `XXX.td` | TableGen 定义 |
| 7 | `TargetRegistry` | 注册到全局 target 注册表 |

### 3. Clang 集成

```cpp
// clang/lib/Basic/Targets/XXX.cpp
class XXXTargetInfo : public TargetInfo {
  XXXTargetInfo(const Triple &Triple, const TargetOptions &)
    : TargetInfo(Triple) {
    // 设置 data layout
    resetDataLayout("e-i64:64-v16:16-v32:32-n16:32:64");
    // 设置 triple
    // 设置默认地址空间等
  }
};
```

### 4. Intrinsic 定义（两种方式）

**新方式（TableGen，推荐）：**
```tablegen
// IntrinsicsXXX.td
class XXX_Intrinsic<string suffix, list<LLVMType> ret_types,
                    list<LLVMType> param_types>
  : ClangBuiltin<!strconcat("__builtin_xxx_", suffix)>,
    DefaultAttrsIntrinsic<ret_types, param_types>;

def int_xxx_widening_smul :
  XXX_Intrinsic<"widening_smul", [llvm_i32_ty], [llvm_i16_ty, llvm_i16_ty]>;
```

**旧方式（.def 文件）：**
```c
// BuiltinsXXX.def
TARGET_BUILTIN(__builtin_xxx_widening_smul, "SiSsSs", "nc", "")
// TYPE: Si=signed int, Ss=signed short
// ATTRS: n=NoThrow, c=Const
```

### 5. TargetTransformInfo (TTI)

TTI 是优化 Pass 查询目标信息的 API：

```cpp
class XXXTTIImpl : public BasicTTIImplBase<XXXTTIImpl> {
  // 示例：告诉优化器某指令的成本
  InstructionCost getInstructionCost(unsigned Opcode, Type *Ty) {
    if (Opcode == Instruction::Mul && Ty->isIntegerTy(16))
      return 1;  // 16-bit 乘法成本为 1（硬件支持）
    return BasicTTIImplBase::getInstructionCost(Opcode, Ty);
  }
  
  // 示例：告诉优化器某 intrinsic 是否免费
  bool isFreeToExpandScalar(unsigned Opcode) {
    // 某些操作在目标上是免费的
    return false;
  }
};
```

### 6. 注入自定义 Pass

**Middle-end（通过 PassBuilder callbacks）：**
```cpp
void XXXTargetMachine::registerPassBuilderCallbacks(PassBuilder &PB) {
  PB.registerPipelineStartEPCallback(
    [](ModulePassManager &MPM, OptimizationLevel Level) {
      MPM.addPass(XXXCustomPass());
    });
}
```

**Backend（通过 TargetPassConfig）：**
```cpp
bool XXXPassConfig::addInstSelector() {
  addPass(createXXXISelPass(*getTM(), OptLevel));
  return false;
}
```

### 7. MC 层骨架

| 类 | 职责 |
|----|------|
| `MCAsmInfo` | 汇编语法（注释符、指令分隔符等） |
| `MCSubtargetInfo` | 子目标特性（CPU 特性、feature 字符串） |
| `MCInstrInfo` | 指令信息（操作码、操作数描述） |
| `MCRegisterInfo` | 寄存器信息（编号、别名、编码） |

## 实践观察

### 实验 1：不同 target 的 data layout

```
x86_64:  e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128
NVPTX:   e-i64:64-i128:128-v16:16-v32:32-n16:32:64
```

**解读：**
- `e` = little-endian
- `m:e` = ELF mangling
- `i64:64` = 64-bit 整数对齐 64-bit
- `v16:16` = 16-bit 向量对齐 16-bit
- `n16:32:64` = 原生整数宽度 16, 32, 64

### 实验 2：target-specific function attributes

```llvm
attributes #0 = {
  "target-cpu"="x86-64"
  "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87"
  "tune-cpu"="generic"
  "stack-protector-buffer-size"="8"
  "frame-pointer"="all"
}
```

这些属性由 TargetInfo 生成，优化 Pass 通过 SubtargetInfo 读取它们。

### 实验 3：NVPTX 后端注入的自定义 Pass

```
Pass Arguments: ... -nvptx-aa -nvvm-reflect -nvptx-assign-valid-global-names
  -generic-to-nvvm -nvptx-lower-args -nvptx-lower-alloca
  -infer-address-spaces -nvptx-atomic-lower -nvptx-lower-ctor-dtor
  -nvptx-lower-unreachable -nvptx-isel -nvptx-proxyreg-erasure
  -nvptx-peephole ...
```

**NVPTX 自定义 Pass 分类：**
- **Address Space**: `infer-address-spaces`, `nvptx-aa`
- **Lowering**: `nvvm-reflect`, `generic-to-nvvm`, `nvptx-lower-args`,
  `nvptx-lower-alloca`, `nvptx-atomic-lower`, `nvptx-lower-ctor-dtor`,
  `nvptx-lower-unreachable`
- **Selection**: `nvptx-isel`
- **Post-selection**: `nvptx-proxyreg-erasure`, `nvptx-peephole`

## 关键收获

1. **Target 信息流向**：TargetInfo → SubtargetInfo → TargetLowering → TTI → 优化 Pass
2. **Intrinsic 是桥梁**：连接源语言 → LLVM IR → 后端指令选择
3. **TTI 控制优化方向**：成本模型决定向量化、循环展开等策略
4. **PassBuilder callbacks**：middle-end 注入点；**TargetPassConfig**：backend 注入点
5. **MC 层是汇编/机器码接口**：与 IR 层独立，负责最终输出
6. **Backend vs Middle-end 选择**：
   - IR 层：可复用、与目标无关、容易测试
   - Machine IR 层：需要硬件细节、目标特定、更复杂

## 待探索

- [ ] 实现一个完整的自定义 TTI cost model
- [ ] 通过 PassBuilder callback 注入自定义 Pass
- [ ] 创建自定义 intrinsic 并端到端测试
