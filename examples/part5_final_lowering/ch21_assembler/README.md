# Chapter 21: Getting Started with the Assembler

## 概述

Assembler 将文本汇编代码转换为二进制 object 文件：
- **输入**：汇编代码（.s 文件）
- **输出**：目标文件（.o 文件，ELF/Mach-O/COFF 格式）
- **关键步骤**：Fixup 插入、约束松弛、重定位记录

## 汇编到二进制的三步流程

```
┌─────────────────────────────────────────────────────────────┐
│  1. 解析汇编指令                                            │
│     文本 → MCInst (Machine Code Instruction)                │
├─────────────────────────────────────────────────────────────┤
│  2. 编码指令                                                │
│     MCInst → 二进制字节 (MCCodeEmitter)                     │
│     插入 Fixup (未解析的地址引用)                            │
├─────────────────────────────────────────────────────────────┤
│  3. 生成 Object 文件                                        │
│     二进制字节 + 重定位信息 → ELF/Mach-O/COFF               │
│     (MCAsmBackend + MCObjectTargetWriter)                   │
└─────────────────────────────────────────────────────────────┘
```

## 关键组件

### 1. MCAsmBackend

处理 fixup 和松弛（relaxation）：

```cpp
class XXXAsmBackend : public MCAsmBackend {
  // 应用 fixup
  void applyFixup(const MCAssembler &Asm, const MCFixup &Fixup,
                  const MCValue &Target, MutableArrayRef<char> Data,
                  uint64_t Value, bool IsResolved) const override;
  
  // 松弛指令（优化分支距离）
  bool mayNeedRelaxation(const MCInst &Inst) const override;
  
  // 提供 MCObjectTargetWriter
  std::unique_ptr<MCObjectTargetWriter> createObjectTargetWriter() const override;
};
```

### 2. MCCodeEmitter

编码指令为二进制：

```cpp
class XXXMCCodeEmitter : public MCCodeEmitter {
  void encodeInstruction(const MCInst &MI, SmallVectorImpl<char> &CB,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override {
    uint64_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
    support::endian::write(CB, Bits, support::little);
    
    if (hasSymbolicOperand(MI)) {
      Fixups.push_back(MCFixup::create(Offset, Expr, Kind));
    }
  }
};
```

### 3. MCObjectTargetWriter

生成特定格式的重定位：

```cpp
class XXXObjectWriter : public MCObjectTargetWriter {
  bool recordRelocation(MCAssembler &Asm, const MCAsmLayout &Layout,
                        const MCFragment *Fragment, const MCFixup &Fixup,
                        MCValue &Target, uint64_t &FixedValue) const override {
    if (Target.getSymA()->getSymbol().isExternal()) {
      Type = ELF::R_X86_64_PLT32;
      Writer->addRelocation(Symbol, Fragment->getParent(), Type, Offset);
    }
    return true;
  }
};
```

## 实践观察

### 函数调用与重定位

**汇编**:
```asm
callq external_func@PLT    # 编码: e8 00 00 00 00 (占位符)
```

**Object 反汇编**:
```
11: e8 00 00 00 00    callq 0x16    # 占位符
```

**重定位**:
```
Offset   Type              Symbol's Name
0x12     R_X86_64_PLT32    external_func - 4
```

**符号表**:
```
U external_func          # U = Undefined (外部符号)
T simple_add             # T = Text (代码段)
```

## 关键收获

1. **Assembler 是编译器后端与二进制工具的边界**
2. **三步流程**：解析 → 编码 → 写入
3. **Fixup 是未解析的地址引用**：编码时填入占位符
4. **重定位记录符号引用**：链接器解析最终地址
5. **外部符号产生重定位**：callq func@PLT → R_X86_64_PLT32
6. **链接器最终解析地址**：重定位 → 实际偏移

## 全书总结

| Part | Chapter | 主题 |
|------|---------|------|
| Part 1 | Ch1-6 | 基础：构建、IR、Pass、TableGen |
| Part 2 | Ch7-10 | 中端：IR、Pass、调试 |
| Part 3 | Ch11-13 | 后端入门：MIR、MC、Pipeline |
| Part 4 | Ch14-17 | 指令选择：IR Building、Legalization、Selection |
| Part 5 | Ch18-21 | 最终优化：调度、寄存器、栈、汇编器 |

**完整后端开发流程**：
```
LLVM IR → 指令选择 → 合法化 → 寄存器分配 → 栈布局 → 汇编输出 → Object 文件
```
