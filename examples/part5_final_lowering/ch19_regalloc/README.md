# Chapter 19: Register Allocation

## 概述

Register Allocation 将无限虚拟寄存器映射到有限物理寄存器：
- **目标**：最小化 spill（溢出到内存）
- **可选但重要**：影响性能的关键优化
- **核心概念**：Live Interval（活跃区间）、Slot Index、Spill/Reload

## 寄存器分配流程

```
┌─────────────────────────────────────────────────────────────┐
│  1. Pre-RA (指令选择后)                                     │
│     虚拟寄存器，SSA 形式                                    │
├─────────────────────────────────────────────────────────────┤
│  2. Register Coalescing (寄存器合并)                        │
│     合并 COPY 指令，减少寄存器使用                          │
├─────────────────────────────────────────────────────────────┤
│  3. Register Allocation (寄存器分配)                        │
│     虚拟寄存器 → 物理寄存器                                 │
│     可能产生 spill code                                     │
├─────────────────────────────────────────────────────────────┤
│  4. Post-RA (寄存器分配后)                                  │
│     非 SSA 形式，物理寄存器                                 │
│     Prologue/Epilogue 插入                                  │
└─────────────────────────────────────────────────────────────┘
```

## 目标必须实现的 Hook

### Spill Code 生成

```cpp
class XXXInstrInfo : public TargetInstrInfo {
  // 存储寄存器到栈槽
  void storeRegToStackSlot(MachineBasicBlock &MBB,
                           MachineBasicBlock::iterator MBBI,
                           Register SrcReg, bool isKill, int FI,
                           const TargetRegisterClass *RC,
                           const TargetRegisterInfo *TRI,
                           Register VReg) const override {
    // 生成 store 指令
    BuildMI(MBB, MBBI, DL, get(XXX::STORE), TRI)
        .addReg(SrcReg)
        .addFrameIndex(FI);
  }
  
  // 从栈槽加载到寄存器
  void loadRegFromStackSlot(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator MBBI,
                            Register DestReg, int FI,
                            const TargetRegisterClass *RC,
                            const TargetRegisterInfo *TRI) const override {
    // 生成 load 指令
    BuildMI(MBB, MBBI, DL, get(XXX::LOAD), DestReg)
        .addFrameIndex(FI);
  }
};
```

### 可选优化

```cpp
// 是否合并两个寄存器
bool shouldCoalesce(const MachineInstr &MI,
                    const TargetRegisterInfo *TRI) const override;

// 分配顺序（物理寄存器尝试顺序）
// 在 TableGen 中设置 AltOrders
def GPR32 : RegisterClass<..., (add R0, R1, R2, R3), AltOrders = [...]>;

// 分配提示（首选寄存器）
void getRegAllocationHints(Register Reg, ...) const override;

// 启用子寄存器活跃追踪
bool enableSubRegLiveness() const override { return true; }
```

## Slot Index

### 概念

```
Slot Index = 指令编号 + Slot 阶段

Slot 阶段：
- B (Block): 基本块开始
- E (Early-clobber): 早期破坏（定义不能与输入共享寄存器）
- R (Register): 常规执行（定义开始，最后使用结束）
- D (Dead): 死亡点
```

### 示例

```
0B   bb.0
16B  %3:gpr32 = COPY $w0      # Slot: 16R (定义)
32B  %4:gpr32 = ADD %3, %2    # Slot: 32R (使用 %3)
48B  B %bb.1

Live Interval of %3: [16R, 32R)
```

### 维护 Slot Index

```cpp
// 添加指令时
SlotIndexes->insertMachineInstrInMaps(MI);

// 删除指令时
SlotIndexes->removeMachineInstrFromMaps(MI);

// 查询
MachineBasicBlock *MBB = SlotIndexes->getMBBFromIndex(Index);
SlotIndex Start = SlotIndexes->getMBBStartIdx(MBB);
```

## Live Interval

### 概念

```
Live Interval = 一组 Slot Index 范围 + VNInfo

示例：
Machine IR:
  80B   %10 = COPY $w0
  320B  %10 = ADD %10, %2
  368B  bb.2:
  400B  $w0 = COPY %10

Live Interval of %10:
  Segments: [80R, 320R:0), [320R, 368B:1), [368B, 400R:2)
  VNInfo: 0@80R, 1@320R, 2@368B-phi
```

### 关键特性

- **保持 SSA 形式**：即使 Machine IR 已非 SSA
- **VNInfo**：记录每个 SSA 值的定义位置
- **Phi 定义**：`2@368B-phi` 表示 phi 节点

### 使用 Live Interval

```cpp
// 查询活跃区间
LiveInterval &LI = LIS->getInterval(Reg);

// 检查某点是否活跃
if (LI.liveAt(Index)) { ... }

// 查找到达定义
VNInfo *VNI = LI.getVNInfoAt(UseIndex);
if (!VNI->isPHIDef()) {
  SlotIndex DefIndex = VNI->def;
  MachineInstr *DefMI = LIS->getInstructionFromIndex(DefIndex);
}
```

### 维护 Live Interval

```cpp
// 创建新虚拟寄存器
LIS->createEmptyInterval(VReg);

// 创建并计算区间
LIS->createAndComputeVirtRegInterval(VReg);

// 移除使用后收缩
LIS->shrinkToUses(LI);

// 添加使用后扩展
LIS->extendToIndices(LI, Indices);
```

## 实践观察

### 实验 1：高寄存器压力

**LLVM IR**:
```llvm
define i32 @high_pressure(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e) {
  %t1 = add i32 %a, %b
  %t2 = add i32 %c, %d
  %t3 = mul i32 %t1, %t2
  %t4 = add i32 %t3, %e
  %t5 = sub i32 %t4, %a
  %t6 = mul i32 %t5, %b
  %t7 = add i32 %t6, %c
  ret i32 %t7
}
```

**NVPTX PTX** (11 个寄存器):
```ptx
.reg .b32 %r<11>;              # 使用 11 个寄存器
ld.param.u32 %r1, [param_0];
ld.param.u32 %r2, [param_1];
add.s32 %r3, %r1, %r2;
ld.param.u32 %r4, [param_2];
ld.param.u32 %r5, [param_3];
add.s32 %r6, %r4, %r5;
ld.param.u32 %r7, [param_4];
mad.lo.s32 %r8, %r3, %r6, %r7;  # mul+add 融合
sub.s32 %r9, %r8, %r1;
mad.lo.s32 %r10, %r9, %r2, %r4;
```

**x86_64 汇编** (使用 6 个物理寄存器):
```asm
leal (%rdi,%rsi), %r9d         # t1 = a + b
leal (%rcx,%rdx), %eax         # t2 = c + d
imull %r9d, %eax               # t3 = t1 * t2
addl %r8d, %eax                # t4 = t3 + e
subl %edi, %eax                # t5 = t4 - a
imull %esi, %eax               # t6 = t5 * b
addl %edx, %eax                # t7 = t6 + c
```

**观察**：
- NVPTX：使用 11 个虚拟寄存器（%r1-%r11），无 spill
- x86_64：使用 6 个物理寄存器（%edi, %esi, %edx, %ecx, %r8d, %r9d, %eax），高效分配

### 实验 2：长生命周期变量

**LLVM IR**:
```llvm
define i32 @long_live(i32 %x) {
  %a = add i32 %x, 1
  %b = add i32 %a, 2
  %c = add i32 %b, 3
  ...
  %j = add i32 %i, 10
  ret i32 %j
}
```

**NVPTX PTX** (优化为单条指令):
```ptx
.reg .b32 %r<3>;
ld.param.u32 %r1, [long_live_param_0];
add.s32 %r2, %r1, 55;          # 常量折叠：1+2+...+10 = 55
```

**x86_64 汇编** (同样优化):
```asm
leal 55(%rdi), %eax            # 常量折叠
```

**观察**：编译器将 10 次加法优化为 `x + 55`（常量折叠）。

### 实验 3：Phi 节点合并

**LLVM IR**:
```llvm
define i32 @phi_merge(i32 %a, i32 %b, i1 %cond) {
  br i1 %cond, label %then, label %else

then:
  %t1 = add i32 %a, 10
  br label %merge

else:
  %t2 = add i32 %b, 20
  br label %merge

merge:
  %result = phi i32 [%t1, %then], [%t2, %else]
  ret i32 %result
}
```

**NVPTX PTX** (分支消除 phi):
```ptx
@!%p1 bra $L__BB2_2;           # 条件跳转
bra.uni $L__BB2_1;

$L__BB2_1:                     # then
  add.s32 %r6, %r4, 10;
  bra.uni $L__BB2_3;

$L__BB2_2:                     # else
  add.s32 %r6, %r5, 20;

$L__BB2_3:                     # merge (phi 消除)
  st.param.b32 [func_retval0+0], %r6;
```

**x86_64 汇编** (条件移动优化):
```asm
testb $1, %dl
je .LBB2_2                     # 跳转到 else
# then
movl %edi, %eax
addl $10, %eax
retq
.LBB2_2:                       # else
addl $20, %esi
movl %esi, %eax
retq
```

**观察**：
- Phi 节点通过分支消除（两个分支都计算结果）
- x86_64 使用条件跳转，未使用 cmov（因为分支简单）

## 寄存器分配算法

### 主要算法

| 算法 | 说明 | 适用场景 |
|------|------|----------|
| **Linear Scan** | 快速，按区间扫描 | -O0, -O1 |
| **Greedy** | 贪心算法，考虑成本 | -O2, -O3 |
| **PBQP** | 基于配分布尔二次规划 | 研究用途 |

### 成本模型

```cpp
// 分配成本 = spill 成本 + 复制成本 + 寄存器压力
unsigned Cost = 0;
if (needsSpill(VReg)) {
  Cost += SpillCost;           // 内存访问代价
}
Cost += CopyCost;              // 复制指令代价
Cost += RegPressurePenalty;    // 寄存器压力惩罚
```

## 关键收获

1. **目标只需实现 spill hook**：storeRegToStackSlot, loadRegFromStackSlot
2. **Slot Index 唯一标识指令**：编号 + 阶段（B/E/R/D）
3. **Live Interval 保持 SSA**：即使 Machine IR 非 SSA
4. **VNInfo 记录定义**：支持到达定义分析
5. **寄存器合并减少 COPY**：Coalescer 在分配前运行
6. **常量折叠优化**：1+2+...+10 → 55
7. **Phi 消除**：通过分支或条件移动实现
8. **NVPTX 寄存器多**：11 个虚拟寄存器无 spill
9. **x86_64 寄存器少**：高效分配 6 个物理寄存器

## 待探索

- [ ] 实现自定义 spill code 生成
- [ ] 观察 Live Interval 调试输出
- [ ] 实现寄存器合并启发式
