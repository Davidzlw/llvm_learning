# Chapter 15: Instruction Selection: The IR Building Phase

## 概述

IR Building 是指令选择的第一阶段，负责：
1. 将 LLVM IR 转换为 SelectionDAG（SDISel）或 Generic MIR（GlobalISel）
2. **实现目标 ABI（调用约定）**：参数传递、返回值、callee-saved 寄存器

## IR Building 两阶段

```
┌─────────────────────────────────────────────────────────────┐
│  1. IR Building (纯 IR 转换)                                │
│     LLVM IR Instruction → SDNode / Generic MachineInstr     │
│     一对一或一对多映射                                       │
├─────────────────────────────────────────────────────────────┤
│  2. ABI Lowering (调用约定实现)                              │
│     - Formal Arguments: 函数入口参数接收                     │
│     - Call Arguments: 函数调用参数传递                       │
│     - Return Values: 返回值处理                              │
│     - Callee-Saved Registers: 被保存寄存器                   │
└─────────────────────────────────────────────────────────────┘
```

## 调用约定 (Calling Convention)

### TableGen 描述

```tablegen
// 定义调用约定
def CC_H2BLB : CallingConv<[
  // i32 参数放入 R0-R3
  CCIfType<[i32], CCAssignToReg<[R0, R1, R2, R3]>>,
  // 溢出到栈
  CCIfType<[i32], CCAssignToStack<4, 4>>
]>;

// 返回值约定
def RetCC_H2BLB : CallingConv<[
  CCIfType<[i32], CCAssignToReg<[R0]>>
]>;

// Callee-saved 寄存器
def CSR_H2BLB : CalleeSavedRegs<[R4, R5, R6, R7]>;
```

### CCAction 组合

```tablegen
// 嵌套条件
CCIfType<[i32], CCAssignToReg<[R0, R1]>>
// 读作：如果类型是 i32，分配到 R0 或 R1

// 复杂组合
CCIfType<[i64], CCIfInReg<[i32], CCAssignToReg<[R0]>>>
// 读作：如果类型是 i64 且在寄存器中，分配到 R0
```

## SDISel ABI Lowering

### 三个核心方法

```cpp
class XXXTargetLowering : public TargetLowering {
  // 1. 接收形式参数（函数入口）
  SDValue LowerFormalArguments(SDValue Chain, CallingConv::ID CallConv,
                               bool isVarArg,
                               const SmallVectorImpl<ISD::InputArg> &Ins,
                               const SDLoc &DL, SelectionDAG &DAG,
                               SmallVectorImpl<SDValue> &InVals) const override;
  
  // 2. 准备调用参数（函数调用）
  SDValue LowerCall(TargetLowering::CallLoweringInfo &CLI,
                    SmallVectorImpl<SDValue> &InVals) const override;
  
  // 3. 处理返回值
  SDValue LowerReturn(SDValue Chain, CallingConv::ID CallConv,
                      bool isVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      const SmallVectorImpl<SDValue> &OutVals,
                      const SDLoc &DL, SelectionDAG &DAG) const override;
};
```

### LowerFormalArguments 实现

```cpp
SDValue XXXTargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool isVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  
  MachineFunction &MF = DAG.getMachineFunction();
  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(CallConv, isVarArg, MF, ArgLocs, *DAG.getContext());
  
  // 分析参数位置
  for (unsigned i = 0; i < Ins.size(); ++i) {
    CCInfo.AnalyzeFormalArgument(Ins[i], CC_XXX);
  }
  
  // 为每个参数生成 COPY 或 LOAD
  for (auto &VA : ArgLocs) {
    if (VA.isRegLoc()) {
      // 参数在寄存器中：生成 COPY
      unsigned VReg = MF.addLiveIn(VA.getLocReg(), RC);
      SDValue ArgValue = DAG.getCopyFromReg(Chain, DL, VReg, VA.getValVT());
      InVals.push_back(ArgValue);
    } else {
      // 参数在栈中：生成 LOAD
      int FrameIdx = MFI.CreateFixedObject(Size, Offset, true);
      SDValue FINode = DAG.getFrameIndex(FrameIdx, PtrVT);
      SDValue Load = DAG.getLoad(VA.getValVT(), DL, Chain, FINode, PtrInfo);
      InVals.push_back(Load);
    }
  }
  
  return Chain;
}
```

### 自定义 SDNode

```tablegen
// 定义 CALL 节点
def XXXcall : SDNode<"XXXISD::CALL", SDT_XXXCall,
                     [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue, SDNPVariadic]>;
```

```cpp
// 使用自定义节点
SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);
Chain = DAG.getNode(XXXISD::CALL, DL, NodeTys, Ops);
```

### 栈帧处理

```cpp
// 创建栈槽
int FrameIdx = MFI.CreateFixedObject(ArgSize, ArgOffset, true);

// 创建 FrameIndex 节点
SDValue FINode = DAG.getFrameIndex(FrameIdx, PtrVT);

// 创建 MachinePointerInfo
MachinePointerInfo PtrInfo = MachinePointerInfo::getFixedStack(MF, FrameIdx);
```

## GlobalISel ABI Lowering

### CallLowering 类

```cpp
class XXXCallLowering : public CallLowering {
  bool lowerFormalArguments(MachineIRBuilder &MIRBuilder,
                           const Function &F,
                           ArrayRef<ArrayRef<Register>> VRegs) const override;
  
  bool lowerCall(MachineIRBuilder &MIRBuilder,
                 CallLoweringInfo &Info) const override;
  
  bool lowerReturn(MachineIRBuilder &MIRBuilder,
                   const Function *F,
                   ArrayRef<Register> VRegs) const override;
};
```

### Assigner 和 Handler

```cpp
// 分配器：确定参数位置
struct IncomingValueAssigner : public CallLowering::IncomingValueAssigner {
  bool assignArg(Register VReg, const CCValAssign &VA,
                 CCState &State) const override {
    return AssignFn(ValNo, ValVT, LocVT, LocInfo, Flags, State);
  }
};

// 处理器：实现参数传递
struct IncomingValueHandler : public CallLowering::IncomingValueHandler {
  void assignValueToReg(Register ValVReg, Register PhysReg,
                       const CCValAssign &VA) override {
    // 生成 COPY 指令
  }
  
  void assignValueToAddress(Register ValVReg, Register Addr,
                           LLT MemTy, const CCValAssign &VA) override {
    // 生成 LOAD 指令
  }
};
```

## 实践观察

### 实验 1：NVPTX 参数传递（参数内存）

**LLVM IR**:
```llvm
define i32 @callee(i32 %a, i32 %b, i32 %c, i32 %d) { ... }
```

**PTX 输出** (参数通过内存传递):
```ptx
.visible .func (.param .b32 func_retval0) callee(
    .param .b32 callee_param_0,
    .param .b32 callee_param_1,
    .param .b32 callee_param_2,
    .param .b32 callee_param_3
) {
    ld.param.u32 %r1, [callee_param_0];
    ld.param.u32 %r2, [callee_param_1];
    ...
}
```

**观察**：NVPTX 使用参数内存（`.param`），通过 `ld.param` 加载。

### 实验 2：x86_64 参数传递（寄存器传参）

**LLVM IR**:
```llvm
define i32 @callee(i32 %a, i32 %b, i32 %c, i32 %d) { ... }
```

**x86_64 汇编** (System V ABI):
```asm
callee:
    # 参数在 %edi, %esi, %edx, %ecx (System V ABI)
    addl %edi, %esi
    leal (%rdx,%rcx), %eax
    addl %esi, %eax
    retq
```

**观察**：x86_64 使用寄存器传参（%edi, %esi, %edx, %ecx）。

### 实验 3：函数调用序列

**LLVM IR**:
```llvm
%ret = call i32 @external_func(i32 %sum, i32 %x, i32 %y)
```

**NVPTX PTX** (callseq 包裹):
```ptx
{ // callseq 0, 0
    .param .b32 param0;
    st.param.b32 [param0+0], %r3;
    .param .b32 param1;
    st.param.b32 [param1+0], %r1;
    .param .b32 param2;
    st.param.b32 [param2+0], %r2;
    .param .b32 retval0;
    call.uni (retval0), external_func, (param0, param1, param2);
    ld.param.b32 %r4, [retval0+0];
} // callseq 0
```

**x86_64 汇编**:
```asm
movl %esi, %edx
movl %edi, %esi
leal (%rsi,%rdx), %edi
callq external_func@PLT
```

**观察**：
- NVPTX 使用 `callseq` 标记调用序列边界
- x86_64 将参数放入 %edi, %esi, %edx（System V ABI）

## 关键概念

### sret Demotion

当返回值太大无法放入寄存器时，使用 sret（structure return）降级：
```cpp
// 添加 sret 参数
if (needsSRetDemotion(RetTy)) {
  // 将返回值改为第一个参数（指针）
  // void @func(%struct* sret %retval)
}
```

### CCState 和 CCValAssign

```cpp
// CCState: 管理调用约定的状态
CCState CCInfo(CallConv, isVarArg, MF, ArgLocs, Context);

// CCValAssign: 记录参数/返回值的位置
CCValAssign::isRegLoc()    // 在寄存器中？
CCValAssign::getLocReg()   // 哪个寄存器？
CCValAssign::isMemLoc()    // 在栈中？
CCValAssign::getLocMemOffset()  // 栈偏移？
```

## 关键收获

1. **IR Building 两阶段**：纯 IR 转换 + ABI Lowering
2. **调用约定是核心**：参数传递、返回值、callee-saved 寄存器
3. **TableGen 描述调用约定**：CallingConv, CCAction, CalleeSavedRegs
4. **SDISel 三个方法**：LowerFormalArguments, LowerCall, LowerReturn
5. **GlobalISel 更模块化**：CallLowering + Assigner + Handler
6. **CCState 管理状态**：CCValAssign 记录每个参数的位置
7. **sret 降级大返回值**：结构体返回通过指针参数
8. **callseq 标记调用边界**：确定栈帧大小
9. **不同 ABI 差异巨大**：NVPTX 用参数内存，x86_64 用寄存器

## 待探索

- [ ] 实现完整的 CallingConv TableGen 描述
- [ ] 观察 sret 降级过程
- [ ] 实现自定义 SDNode 用于调用
