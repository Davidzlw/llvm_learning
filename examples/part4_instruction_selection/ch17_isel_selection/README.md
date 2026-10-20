# Chapter 17: Instruction Selection: The Selection Phase and Beyond

## 概述

Selection Phase 是指令选择的最后阶段，负责将**合法但通用的 IR** 转换为**目标特定的 Machine IR**：
- **模式匹配**：使用 TableGen 模式匹配指令序列
- **寄存器库选择**：GlobalISel 特有的 RegBankSelect Pass
- **后续优化**：DAG Combiner、指令重写
- **最终化**：FinalizeISel 清理 MachineFunction

## 指令选择流程

```
┌─────────────────────────────────────────────────────────────┐
│  1. IR Building (Ch15)                                      │
│     LLVM IR → SelectionDAG / Generic MIR                    │
├─────────────────────────────────────────────────────────────┤
│  2. Legalization (Ch16)                                     │
│     非法类型/操作 → 合法类型/操作                            │
├─────────────────────────────────────────────────────────────┤
│  3. RegBankSelect (GlobalISel only)                         │
│     选择寄存器库 (GPR, FPR, VR)                             │
├─────────────────────────────────────────────────────────────┤
│  4. Selection (本章)                                        │
│     Generic MIR → Target-Specific MachineInstr              │
├─────────────────────────────────────────────────────────────┤
│  5. FinalizeISel                                            │
│     清理 MachineFunction，准备后续 Pass                     │
└─────────────────────────────────────────────────────────────┘
```

## 选择模式 (Selection Patterns)

### TableGen 模式定义

```tablegen
// 简单模式：直接匹配
def : Pat<(i32 GPR32:$src), (COPY GPR32:$src)>;

// 复合模式：指令融合
def : Pat<(add i32:$a, i32:$b), (ADD32rr i32:$a, i32:$b)>;

// 复杂模式：地址模式
def addrmode : ComplexPattern<i32, 4, "SelectAddr">;
def : Pat<(load addrmode:$addr), (LD32 addrmode:$addr)>;

// 模式片段：复用匹配逻辑
def PatFrag muladd : (patfrag) {
  let Operands = [i32, i32, i32];
  let Code = [{ return curDAG->getNode(ISD::MUL, ...) }];
}
```

### 高级模式

```tablegen
// ComplexPattern：C++ 函数匹配
def addrmode : ComplexPattern<i32, 4, "SelectAddr", [], []>;

// SDNodeXForm：节点变换
def XForm : SDNodeXForm<add, [{
  return CurDAG->getNode(ISD::ADD, ...);
}]>;

// GINodeEquiv：GlobalISel 节点等价
def : GINodeEquiv<G_EXTRACT_VECTOR_ELT, vector_extract>;
```

## 寄存器库选择 (RegBankSelect)

### 目标

优化**跨寄存器库的拷贝**：
- GPR（通用寄存器）↔ FPR（浮点寄存器）
- 减少不必要的类型转换

### RegisterBankInfo

```cpp
class XXXRegisterBankInfo : public RegisterBankInfo {
  // 获取指令的映射
  const InstructionMapping &getInstrMapping(const MachineInstr &MI) const override {
    unsigned Opc = MI.getOpcode();
    switch (Opc) {
    case TargetOpcode::G_ADD:
      // 返回 GPR 映射
      return getMapping(MI, {GPRIdx, GPRIdx, GPRIdx});
    case TargetOpcode::G_FADD:
      // 返回 FPR 映射
      return getMapping(MI, {FPRIdx, FPRIdx, FPRIdx});
    }
  }
};
```

### PartialMapping / ValueMapping

```cpp
// PartialMapping：部分映射
const RegisterBankInfo::PartialMapping PartMappings[] = {
    {0, 16, GPRBRegBank},  // 16位，GPR 库
    {0, 32, GPRBRegBank},  // 32位，GPR 库
};

// ValueMapping：值映射
const RegisterBankInfo::ValueMapping ValueMappings[] = {
    {PartMappings + PMI_GPRB16, 1},  // 16位值
    {PartMappings + PMI_GPRB32, 1},  // 32位值
};

// InstructionMapping：指令映射
const RegisterBankInfo::InstructionMapping InstrMappings[] = {
    {G_ADD, /*Cost*/1, {/*Dst*/ValueMappings[1], /*Src1*/ValueMappings[1], /*Src2*/ValueMappings[1]}, 0},
};
```

## Custom Inserter

### 用途

在指令选择后展开**伪指令**为复杂序列：

```tablegen
// 标记需要自定义插入器
let usesCustomInserter = true in
def LD16imm16 : H2BLBPseudoInstruction<...>;
```

```cpp
// 实现自定义插入器
MachineBasicBlock *
XXXTargetLowering::EmitInstrWithCustomInserter(MachineInstr &MI,
                                               MachineBasicBlock *BB) const {
  switch (MI.getOpcode()) {
  case H2BLB::LD16imm16:
    return emitLDimm(MI);  // 展开为多条指令
  }
  return nullptr;
}
```

## DAG Combine 优化

### SDISel 优化

```cpp
// 设置自定义重写
setTargetDAGCombine(ISD::ADD);

// 实现重写
SDValue XXXTargetLowering::PerformDAGCombine(SDNode *N, DAGCombinerInfo &DCI) const {
  if (N->getOpcode() == ISD::ADD) {
    // 模式匹配：add (mul a, b), c → mad a, b, c
    if (auto *Mul = dyn_cast<SDNode>(N->getOperand(0))) {
      if (Mul->getOpcode() == ISD::MUL) {
        return DAG.getNode(XXXISD::MAD, DL, VT, Mul->getOperand(0), 
                          Mul->getOperand(1), N->getOperand(1));
      }
    }
  }
  return SDValue();
}
```

### GlobalISel 优化

```cpp
// 使用 Combiner 规则
class XXXCombinerRule : public CombinerRule {
  bool match(MachineInstr &MI) override {
    // 匹配模式
  }
  void apply(MachineInstr &MI) override {
    // 应用变换
  }
};
```

## 调试指令选择

### SDISel 调试

```bash
# 查看模式匹配过程
llc -debug-only=isel test.ll 2>&1 | grep "ISEL:"

# 输出示例
ISEL: Starting selection on root node: t9: v2i32 = add t2, t2
ISEL: Starting pattern match
  Initial Opcode index to 31041
  Match failed at index 31046
  Continuing at 158464
```

### GlobalISel 调试

```bash
# 查看选择过程
llc -debug-only=aarch64-isel test.ll 2>&1

# 输出示例
Selecting: 
  %8:gpr(s32) = G_ADD %2:gpr, %3:gpr
10: GIM_SwitchOpcode(MIs[0], [51, 795), Default=357167, JumpTable...) // Got=51
2997: GIM_SwitchType(MIs[0]->getOperand(0), [2, 24), Default=21984, ...)
```

## 实践观察

### 实验 1：指令融合 (mul+add → mad)

**LLVM IR**:
```llvm
define i32 @arithmetic(i32 %a, i32 %b, i32 %c) {
  %mul = mul i32 %a, %b
  %add = add i32 %mul, %c
  %sub = sub i32 %add, %a
  ret i32 %sub
}
```

**NVPTX PTX** (mad 融合):
```ptx
mad.lo.s32 %r4, %r1, %r2, %r3;    # mul+add 融合为 mad
sub.s32  %r5, %r4, %r1;
```

**x86_64 汇编** (imul+lea):
```asm
imull %edi, %esi              # 乘法
leal  (%rsi,%rdx), %eax       # 加法用 lea
subl  %edi, %eax              # 减法
```

**观察**：
- NVPTX：`mul+add` 融合为 `mad.lo.s32`（乘加指令）
- x86_64：使用 `imul` + `leal`（lea 可以做加法）

### 实验 2：复杂地址模式

**LLVM IR**:
```llvm
define i32 @load_offset(i32* %ptr, i32 %offset) {
  %addr = getelementptr i32, i32* %ptr, i32 %offset
  %val = load i32, i32* %addr
  ret i32 %val
}
```

**NVPTX PTX** (显式地址计算):
```ptx
mul.wide.s32 %rd2, %r1, 4;        # offset * 4 (字节偏移)
add.s64    %rd3, %rd1, %rd2;      # ptr + offset*4
ld.u32     %r2, [%rd3];           # 加载
```

**x86_64 汇编** (复杂地址模式):
```asm
movslq %esi, %rax                 # 符号扩展到 64 位
movl   (%rdi,%rax,4), %eax        # 复杂地址：base + index*scale
```

**观察**：
- x86_64：使用 `(%rdi,%rax,4)` 复杂地址模式（base + index*scale）
- NVPTX：显式计算地址（mul.wide + add）

### 实验 3：条件选择 (select → max/cmov)

**LLVM IR**:
```llvm
define i32 @select_max(i32 %a, i32 %b) {
  %cmp = icmp sgt i32 %a, %b
  %result = select i1 %cmp, i32 %a, i32 %b
  ret i32 %result
}
```

**NVPTX PTX** (max 指令):
```ptx
max.s32 %r3, %r1, %r2;    # 直接使用 max 指令
```

**x86_64 汇编** (cmov 条件移动):
```asm
movl   %esi, %eax         # 默认返回 b
cmpl   %esi, %edi         # 比较 a > b
cmovgl %edi, %eax         # 如果 a > b，移动 a 到 eax
```

**观察**：
- NVPTX：直接使用 `max.s32` 指令
- x86_64：使用 `cmovgl`（条件移动）避免分支

### 实验 4：向量 SIMD 选择

**LLVM IR**:
```llvm
define <4 x i32> @vec_add(<4 x i32> %a, <4 x i32> %b) {
  %sum = add <4 x i32> %a, %b
  ret <4 x i32> %sum
}
```

**NVPTX PTX** (标量化):
```ptx
ld.param.v4.u32 {%r1, %r2, %r3, %r4}, [vec_add_param_0];
ld.param.v4.u32 {%r5, %r6, %r7, %r8}, [vec_add_param_1];
add.s32 %r9, %r4, %r8;        # 逐个元素相加
add.s32 %r10, %r3, %r7;
add.s32 %r11, %r2, %r6;
add.s32 %r12, %r1, %r5;
st.param.v4.b32 [func_retval0+0], {%r12, %r11, %r10, %r9};
```

**x86_64 汇编** (SSE SIMD):
```asm
paddd %xmm1, %xmm0    # 单条 SIMD 指令完成 4 个 i32 加法
```

**观察**：
- NVPTX：标量化为 4 个标量加法（GPU 无 SIMD 寄存器）
- x86_64：使用 `paddd` SSE 指令（真正的 SIMD）

## 关键概念

### FinalizeISel

```cpp
// 冻结保留寄存器集合
void TargetLowering::finalizeLowering(MachineFunction &MF) const {
  // 标记为已选择
  MF.getProperties().set(MachineFunctionProperties::Property::Selected);
  // 冻结保留寄存器
  MF.getFrameInfo().setHasStackMap(false);
}
```

### 自定义 finalizeLowering

```cpp
void XXXTargetLowering::finalizeLowering(MachineFunction &MF) const {
  if (MF.getProperties().hasProperty(
          MachineFunctionProperties::Property::Selected))
    return;  // 已处理
  
  // 自定义清理工作
  ...
  
  TargetLowering::finalizeLowering(MF);  // 调用父类
}
```

## SDISel vs GlobalISel 对比

| 特性 | SDISel | GlobalISel |
|------|--------|------------|
| **模式匹配** | TableGen DAG 模式 | TableGen + GINodeEquiv |
| **寄存器库** | 无（隐式） | RegBankSelect Pass |
| **优化** | DAG Combine | Combiner 规则 |
| **调试** | -debug-only=isel | -debug-only=xxx-isel |
| **Custom Inserter** | EmitInstrWithCustomInserter | 类似 |
| **复杂度** | 状态机难调试 | 更模块化 |

## 关键收获

1. **Selection Phase 是最后阶段**：Generic IR → Target-Specific MIR
2. **TableGen 模式是核心**：声明式描述指令匹配
3. **ComplexPattern 匹配复杂地址**：C++ 函数实现灵活匹配
4. **RegBankSelect 优化拷贝**：减少跨寄存器库转换
5. **Custom Inserter 展开伪指令**：处理复杂代码序列
6. **DAG Combine 优化**：mul+add → mad 融合
7. **FinalizeISel 清理**：冻结保留寄存器，准备后续 Pass
8. **调试用 -debug-only=isel**：查看模式匹配过程
9. **SIMD 选择差异大**：x86 用 paddd，NVPTX 标量化

## 待探索

- [ ] 实现完整的 TableGen 选择模式
- [ ] 实现 ComplexPattern 匹配地址模式
- [ ] 使用 DAG Combine 进行指令融合优化
