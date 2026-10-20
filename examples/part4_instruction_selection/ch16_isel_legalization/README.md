# Chapter 16: Instruction Selection: The Legalization Phase

## 概述

Legalization 阶段负责将**非法的通用 IR** 转换为**目标支持的操作**：
- **类型合法化**：将不支持的类型（如 i8, i64）转换为支持的类型（如 i32）
- **操作合法化**：将不支持的操作（如某些乘法）转换为支持的序列或库调用

## 合法化动作 (Legalization Actions)

| 动作 | 说明 | 示例 |
|------|------|------|
| **Legal** | 目标原生支持 | i32 add 在 x86 |
| **Promote** | 类型提升（小→大） | i8 → i32 |
| **Expand** | 操作展开 | i64 add → 两个 i32 add |
| **Soften** | 浮点→整数 | float → i32 |
| **Scalarize** | 向量→标量 | <3 x i8> → 3 个 i8 |
| **Split** | 拆分类型 | i64 → 2 x i32 |
| **Widen** | 扩展类型 | <3 x i8> → <4 x i8> |
| **LibCall** | 库函数调用 | float sqrt → sqrtf() |
| **Custom** | 自定义实现 | 特殊乘法指令 |

## SDISel 合法化

### 两阶段流程

```
┌─────────────────────────────────────────────────────────────┐
│  1. Type Legalization (类型合法化)                           │
│     将所有非法类型转换为合法类型                              │
│     i8, i64, <3 x i8> → i16, i32, <4 x i16>                │
├─────────────────────────────────────────────────────────────┤
│  2. Operation Legalization (操作合法化)                      │
│     对合法类型上的操作应用合法化动作                          │
│     i32 MUL → Expand / LibCall / Custom                     │
└─────────────────────────────────────────────────────────────┘
```

### 关键概念：Legal Types

```cpp
// 在 TargetLowering 构造函数中设置
addRegisterClass(MVT::i16, &H2BLB::GPR16RegClass);
addRegisterClass(MVT::i32, &H2BLB::GPR32RegClass);
computeRegisterProperties(Subtarget.getRegisterInfo());
```

**重要**：一旦类型被标记为 legal，该类型上的**所有操作**都被假定为 legal。
- 如果 i64 是 legal，但 i64 mul 不支持，必须显式设置操作合法化

### 操作合法化设置

```cpp
// 浮点加法 → 库调用
setOperationAction(ISD::FADD, MVT::f32, LibCall);

// 截断存储 → 展开
setOperationAction(ISD::TRUNCSTORE, MVT::i16, Expand);

// 乘法 → 自定义
setOperationAction(ISD::MUL, MVT::i32, Custom);
```

### 自定义合法化

```cpp
SDValue XXXTargetLowering::LowerOperation(SDValue Op, SelectionDAG &DAG) const {
  switch (Op.getOpcode()) {
  case ISD::MUL:
    return lowerMUL(Op, DAG);
  }
  return SDValue();
}

SDValue XXXTargetLowering::lowerMUL(SDValue Op, SelectionDAG &DAG) const {
  // 检查是否可以自定义合法化
  if (PlainLHS.getValueType() != MVT::i16)
    return SDValue();  // 返回空表示失败，回退到 Expand
  
  // 生成自定义节点
  unsigned Opcode = isSigned ? H2BLBISD::WIDENING_SMUL : H2BLBISD::WIDENING_UMUL;
  return DAG.getNode(Opcode, SDLoc(Op), ValTy, PlainLHS, PlainRHS);
}
```

## GlobalISel 合法化

### 架构

```
┌─────────────────────────────────────────────────────────────┐
│  LegalizerInfo (描述合法化规则)                              │
│    └── LegalizeRuleSet (每个操作的规则集)                    │
│          ├── legalForTypesWithMemDesc()                      │
│          ├── legalIf()                                       │
│          ├── lowerIf()                                       │
│          ├── scalarize()                                     │
│          └── lower()                                         │
├─────────────────────────────────────────────────────────────┤
│  Legalizer Pass (执行合法化)                                 │
│    └── LegalizerHelper (辅助工具)                            │
└─────────────────────────────────────────────────────────────┘
```

### 规则集 API

```cpp
// 在 LegalizerInfo 构造函数中设置
getActionDefinitionsBuilder(G_ADD)
    .legalFor({s16, s32})                    // s16, s32 合法
    .clampScalar(0, s16, s32)                // 限制范围
    .lowerIf([=](const LegalityQuery &Q) {   // 条件降低
      return Q.Types[0].getSizeInBits() > 32;
    })
    .scalarize(0)                            // 向量标量化
    .lower();                                // 其余降低

getActionDefinitionsBuilder(G_LOAD)
    .legalForTypesWithMemDesc({
      {s16, p0, s16, 8},   // 16位加载，地址空间0，对齐8
      {s32, p0, s32, 8}    // 32位加载，地址空间0，对齐8
    })
    .lowerIf([=](const LegalityQuery &Q) {
      return Q.Types[0].isScalar() &&
             Q.Types[0] != Q.MMODescrs[0].MemoryTy;
    })
    .legalIf([=](const LegalityQuery &Q) {
      TypeSize Size = Q.Types[0].getSizeInBits();
      return Size == 16 || Size == 32;
    })
    .scalarize(0)
    .lower();
```

### 自定义合法化

```cpp
// 1. 设置规则
getActionDefinitionsBuilder(G_MUL)
    .customIf([=](const LegalityQuery &Q) {
      const auto &DstTy = Q.Types[0];
      return !DstTy.isVector() && DstTy.getSizeInBits() == 32;
    });

// 2. 实现方法
bool XXXLegalizerInfo::legalizeCustom(
    LegalizerHelper &Helper, MachineInstr &MI,
    LostDebugLocObserver &LocObserver) const {
  switch (MI.getOpcode()) {
  case G_MUL:
    return legalizeMul(MI, MRI, MIRBuilder, Observer);
  }
  return false;
}

// 3. 具体实现
bool XXXLegalizerInfo::legalizeMul(MachineInstr &MI, ...) const {
  // 使用 mi_match 模式匹配
  if (mi_match(LHS, MRI, m_GSExt(m_Reg(PlainLHS))) &&
      mi_match(RHS, MRI, m_GSExt(m_Reg(PlainRHS))))
    isSigned = true;
  
  // 替换为自定义指令
  unsigned Opcode = isSigned ? WIDENING_SMUL : WIDENING_UMUL;
  MI.setDesc(TII.get(Opcode));
  return true;
}
```

## 实践观察

### 实验 1：类型合法化 (i8 → i16/i32)

**LLVM IR**:
```llvm
define i8 @add_i8(i8 %a, i8 %b) {
  %sum = add i8 %a, %b
  ret i8 %sum
}
```

**NVPTX PTX** (i8 提升为 i16，再截断为 i32):
```ptx
ld.param.u8   %rs1, [add_i8_param_0];
ld.param.u8   %rs2, [add_i8_param_1];
add.s16       %rs3, %rs1, %rs2;      # i16 加法
cvt.u32.u16   %r1, %rs3;             # 转换为 i32
and.b32       %r2, %r1, 255;         # 截断为 8 位
st.param.b32  [func_retval0+0], %r2;
```

**x86_64 汇编** (i8 在 32 位寄存器中操作):
```asm
leal (%rdi,%rsi), %eax    # 32位加法
# kill: def $al            # 只使用低 8 位
retq
```

**观察**：
- NVPTX：i8 → i16 加法 → i32 转换 → 截断
- x86_64：直接在 32 位寄存器中操作，用 `kill` 标记高位无效

### 实验 2：i64 类型合法化

**LLVM IR**:
```llvm
define i64 @add_i64(i64 %a, i64 %b) {
  %sum = add i64 %a, %b
  ret i64 %sum
}
```

**NVPTX PTX** (i64 拆分为两个 i32):
```ptx
ld.param.u32  %r1, [add_i64_param_0];     # 低 32 位
ld.param.u32  %r2, [add_i64_param_1];
add.s32       %r3, %r1, %r2;              # 低 32 位相加
ld.param.u32  %r4, [add_i64_param_2];     # 高 32 位
ld.param.u32  %r5, [add_i64_param_3];
addc.s32      %r6, %r4, %r5;              # 带进位加高 32 位
st.param.u32  [func_retval0+0], %r3;      # 存储低 32 位
st.param.u32  [func_retval0+4], %r6;      # 存储高 32 位
```

**x86_64 汇编** (原生 64 位):
```asm
leaq (%rdi,%rsi), %rax    # 原生 64 位加法
retq
```

**观察**：
- NVPTX：i64 拆分为两个 i32，使用 `addc`（带进位加）
- x86_64：原生支持 i64，单条 `leaq` 指令

### 实验 3：向量类型合法化

**LLVM IR**:
```llvm
define <3 x i8> @add_vec3(<3 x i8> %a, <3 x i8> %b) {
  %sum = add <3 x i8> %a, %b
  ret <3 x i8> %sum
}
```

**x86_64 汇编** (非标量向量化):
```asm
# 将 <3 x i8> 打包到 32 位寄存器
movzbl %cl, %eax
movzbl %r8b, %ecx
shll   $8, %ecx
orl    %eax, %ecx
movzbl %r9b, %eax
shll   $16, %eax
orl    %ecx, %eax
movd   %eax, %xmm0
# 对第二个操作数做同样处理
...
paddb  %xmm0, %xmm1       # SIMD 字节加法
movd   %xmm1, %eax        # 解包结果
```

**观察**：<3 x i8> 被打包到 32 位寄存器，使用 SIMD 指令 `paddb`。

### 实验 4：浮点操作合法化

**LLVM IR**:
```llvm
define float @add_float(float %a, float %b) {
  %sum = fadd float %a, %b
  ret float %sum
}
```

**NVPTX PTX** (软件浮点):
```ptx
ld.param.f32  %f1, [add_float_param_0];
ld.param.f32  %f2, [add_float_param_1];
add.f32       %f3, %f1, %f2;
st.param.f32  [func_retval0+0], %f3;
```

**x86_64 汇编** (SSE 硬件浮点):
```asm
addss %xmm1, %xmm0    # SSE 单精度加法
retq
```

**观察**：
- NVPTX：使用 PTX 浮点指令（软件模拟或硬件取决于 GPU）
- x86_64：使用 SSE `addss` 指令

### 实验 5：乘法操作合法化

**LLVM IR**:
```llvm
define i32 @mul_i32(i32 %a, i32 %b) {
  %prod = mul i32 %a, %b
  ret i32 %prod
}
```

**NVPTX PTX**:
```ptx
mul.lo.s32 %r3, %r1, %r2;    # 32位乘法低32位
```

**x86_64 汇编**:
```asm
imull %esi, %eax              # 有符号 32 位乘法
```

**观察**：两个目标都原生支持 i32 乘法。

## SDISel vs GlobalISel 对比

| 特性 | SDISel | GlobalISel |
|------|--------|------------|
| **Legal Types** | 有（有限集合） | 无（精确规则） |
| **规则描述** | 静态（每个类型/操作对） | 程序化（LegalizeRuleSet） |
| **类型范围** | 只处理 legal types | 处理所有可能类型 |
| **自定义** | LowerOperation 回调 | legalizeCustom 方法 |
| **复杂度** | 简单但不够灵活 | 复杂但更精确 |
| **推荐** | 传统后端 | 新项目 |

## 关键 API

### SDISel (TargetLowering)

```cpp
// 设置合法类型
addRegisterClass(MVT::i32, &XXX::GPR32RegClass);

// 设置操作动作
setOperationAction(ISD::MUL, MVT::i32, Custom);
setOperationAction(ISD::FADD, MVT::f32, LibCall);

// 自定义合法化
SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const override;
```

### GlobalISel (LegalizerInfo)

```cpp
// 获取规则构建器
getActionDefinitionsBuilder(G_ADD)
    .legalFor({s32})
    .lowerIf(...)
    .customIf(...);

// 自定义合法化
bool legalizeCustom(LegalizerHelper &Helper, MachineInstr &MI, ...) const;
```

## 关键收获

1. **Legalization 两阶段**：类型合法化 → 操作合法化
2. **SDISel 依赖 Legal Types**：标记合法类型，其余自动处理
3. **GlobalISel 无 Legal Types**：使用程序化规则精确描述
4. **LegalizeRuleSet 是核心**：链式 API 描述复杂规则
5. **自定义合法化是高级手段**：当内置动作不够时使用
6. **类型提升 vs 扩展**：i8 → i32 可以是 promote 或 expand
7. **向量合法化复杂**：可能需要 scalarize、widen 或 split
8. **浮点操作常需 LibCall**：目标不支持时回退到库函数
9. **mi_match 模式匹配**：GlobalISel 中用于识别指令序列

## 待探索

- [ ] 实现完整的 LegalizeRuleSet
- [ ] 观察向量类型的 widen/scarize 过程
- [ ] 实现自定义合法化回调
