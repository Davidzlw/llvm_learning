# Chapter 12: Getting Started with the Machine Code Layer

## 概述

MC 层是 LLVM 后端的最终阶段，负责：
- 汇编语法描述（AsmString）
- 指令编码（Encoding）
- 汇编器（Assembler）和反汇编器（Disassembler）
- 目标文件生成

## MC 层架构

```
┌─────────────────────────────────────────┐
│  Machine Layer (CodeGen)                │
│  MachineInstr, MachineOperand           │
│  TargetInstrInfo, TargetRegisterInfo    │
├─────────────────────────────────────────┤
│  MC Layer                               │
│  MCInst, MCOperand                      │
│  MCInstrInfo, MCRegisterInfo            │
│  MCInstPrinter (反汇编)                 │
│  MCCodeEmitter (汇编编码)               │
│  MCAsmParser (汇编解析)                 │
│  MCDisassembler (反汇编解码)            │
└─────────────────────────────────────────┘
```

## 关键组件

### 1. MCInstPrinter（反汇编打印）

将 MCInst 转换为汇编文本：

```cpp
void XXXInstPrinter::printInstruction(const MCInst *MI, raw_ostream &O) {
  if (PrintAliases && printAliasInstr(MI, O))
    return;
  printInstruction(MI, O);  // TableGen 生成
  printAnnotation(O, MI);
}

void XXXInstPrinter::printOperand(const MCInst *MI, unsigned OpNo,
                                  raw_ostream &O) {
  const MCOperand &Op = MI->getOperand(OpNo);
  if (Op.isReg()) O << getRegisterName(Op.getReg());
  else if (Op.isImm()) O << formatImm(Op.getImm());
  else Op.getExpr()->print(O, &MAI);
}
```

### 2. MCCodeEmitter（汇编编码）

将 MCInst 编码为字节序列：

```cpp
void XXXMCCodeEmitter::encodeInstruction(const MCInst &MI,
    SmallVectorImpl<char> &CB, SmallVectorImpl<MCFixup> &Fixups,
    const MCSubtargetInfo &STI) const {
  uint64_t Encoding = getBinaryCodeForInstr(MI, Fixups, STI);
  support::endian::write<uint32_t>(CB, Encoding, llvm::endianness::little);
}
```

### 3. MCAsmParser（汇编解析）

将汇编文本解析为 MCInst（高度目标相关，需大量手动实现）。

## TableGen 描述

### 汇编语法

```tablegen
def ADDi32rr : Instruction {
  let OutOperandList = (outs int32regs:$dst);
  let InOperandList = (ins int32regs:$src1, int32regs:$src2);
  let AsmString = "add.s32 \t$dst, $src1, $src2";
}
```

### 指令编码

```tablegen
def ADDi32rr : Instruction {
  // ... 操作数 ...
  let Inst{31-24} = 0b00000000;  // 操作码字段
  let Inst{23-20} = 0b0100;      // ALU 操作类型
  let Inst{19-16} = src1;        // 源寄存器1
  let Inst{15-12} = src2;        // 源寄存器2
  let Inst{11-0}  = dst;         // 目标寄存器
}
```

### 编码族分组

```tablegen
// ALU 族
class ALUInst<dag outs, dag ins, string asm> : Instruction {
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asm;
  let Inst{31-24} = 0b00000000;  // ALU 编码前缀
}

// 内存族
class MemInst<dag outs, dag ins, string asm> : Instruction {
  // ...
  let Inst{31-24} = 0b10000000;  // Mem 编码前缀
}
```

## 工具

### llvm-mc

```bash
# 汇编 + 显示编码
echo "addl %edi, %esi" | llvm-mc --arch=x86-64 -show-encoding
# 输出: addl %edi, %esi  # encoding: [0x01,0xfe]

# 反汇编
echo "0x01, 0xf7" | llvm-mc --arch=x86-64 -disassemble
# 输出: addl %esi, %edi

# 汇编为对象文件
llvm-mc --arch=x86-64 input.s -filetype=obj -o output.o
```

### llc 生成汇编

```bash
# 生成 PTX 汇编
llc -march=nvptx64 -mcpu=sm_89 input.ll -filetype=asm -o output.ptx

# 生成 x86 汇编
llc -march=x86-64 input.ll -filetype=asm -o output.s
```

## 实践观察

### 实验 1：x86_64 汇编编码

```
输入: addl %edi, %esi
编码: [0x01, 0xfe]
```

### 实验 2：x86_64 反汇编

```
输入: 0x01, 0xf7
输出: addl %esi, %edi
```

### 实验 3：NVPTX PTX 汇编

```ptx
.visible .func (.param .b32 func_retval0) add(
    .param .b32 add_param_0,
    .param .b32 add_param_1
) {
    .reg .b32 %r<4>;
    ld.param.u32 %r1, [add_param_0];
    ld.param.u32 %r2, [add_param_1];
    add.s32 %r3, %r1, %r2;
    st.param.b32 [func_retval0+0], %r3;
    ret;
}
```

### 实验 4：x86_64 汇编

```asm
add:
    leal (%rdi,%rsi), %eax
    retq
```

## 关键收获

1. **MC 层是汇编级抽象**：MCInst ↔ 汇编文本 ↔ 字节编码
2. **TableGen 生成大部分 MC 代码**：printInstruction, getBinaryCodeForInstr
3. **编码族分组很重要**：提前规划 TableGen 类层次结构
4. **MCInstPrinter 负责反汇编**：MCInst → 汇编文本
5. **MCCodeEmitter 负责编码**：MCInst → 字节序列
6. **MCAsmParser 最复杂**：汇编文本 → MCInst，需大量手动实现
7. **llvm-mc 是测试利器**：验证汇编/反汇编/编码
8. **不是所有指令都需要编码**：伪指令（PHI, COPY）仅存在于 Machine 层

## 待探索

- [ ] 实现完整的 MCAsmParser
- [ ] 自定义指令编码并验证
- [ ] 使用 llvm-mc 测试反汇编器
