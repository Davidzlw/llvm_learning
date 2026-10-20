# Chapter 20: Lowering of the Stack Layout

## 概述

Stack Layout 描述如何组织目标架构的内存空间来建模程序的栈：
- **栈增长方向**：向上（低→高）或向下（高→低）
- **参数位置**：输入/输出参数相对于栈起始位置
- **栈帧组成**：局部变量、spill slots、动态分配、调用参数

## 栈帧布局

```
┌─────────────────────────────────────────┐
│  Caller Frame                           │
│  ┌───────────────────────────────────┐  │
│  │ 当前函数的输入/输出参数            │  │
│  ├───────────────────────────────────┤  │
│  │ 静态局部对象 (编译时已知大小)      │  │
│  ├───────────────────────────────────┤  │
│  │ Spill Slots (寄存器溢出)          │  │
│  ├───────────────────────────────────┤  │
│  │ 动态分配对象 (运行时大小)          │  │
│  ├───────────────────────────────────┤  │
│  │ 下一次调用的参数空间               │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
         ↓ 栈增长方向 (x86: 向下)
```

## 关键组件

### 1. TargetFrameLowering

负责分配栈空间，提供 prologue/epilogue 代码序列：

```cpp
class XXXFrameLowering : public TargetFrameLowering {
  // 发射 prologue (函数入口)
  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override {
    BuildMI(MBB, I, DL, TII.get(XXX::SUBri), SP)
        .addReg(SP).addImm(StackSize);
  }
  
  // 发射 epilogue (函数返回)
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override {
    BuildMI(MBB, I, DL, TII.get(XXX::ADDri), SP)
        .addReg(SP).addImm(StackSize);
  }
};
```

### 2. TargetRegisterInfo

负责展开 frame index 为实际栈地址：

```cpp
void eliminateFrameIndex(MachineBasicBlock::iterator II, ...) const override {
  int Offset = MFI.getObjectOffset(FrameIndex);
  Offset += MFI.getStackSize();  // 转换为相对于 SP SP 的偏移
  
  // 替换 frame index 为 SP + offset
  MI.getOperand(FIOperandNum).ChangeToRegister(XXX::SP, false);
  MI.getOperand(2).setImm(Offset);
}
```

### 3. 寄存器争夺 (RegScavenger)

```cpp
RegScavenger RS;
RS.enterBasicBlockEnd(MBB);
RS.backward(I);  // 反向遍历
Register Reg = RS.FindUnusedReg(&XXX::GPR32RegClass);
```

## 实践观察

### x86_64 栈帧

```asm
large_stack:
    subq $272, %rsp              # Prologue: 分配 272 字节
    movl $999, -128(%rsp)        # 存储到栈
    addq $272, %rsp              # Epilogue: 释放栈
    retq
```

### NVPTX 无显式栈

```ptx
mov.b32 %r1, 999;                # 常量折叠
st.param.b32 [func_retval0+0], %r1;
```

## 关键收获

1. **栈布局三要素**：TargetFrameLowering、TargetRegisterInfo、PEI
2. **Prologue/Epilogue**：分配/释放栈空间
3. **Frame Index 展开**：替换为 SP + offset
4. **寄存器争夺**：RegScavenger 查找可用寄存器
5. **x86_64 栈向下增长**：subq 分配，addq 释放
6. **NVPTX 无显式栈**：使用参数内存和寄存器
