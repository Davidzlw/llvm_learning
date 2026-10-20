# Chapter 18: Instruction Scheduling

## 概述

Instruction Scheduling 是低级优化，根据依赖关系和资源约束重新排列指令顺序：
- **目标**：减少寄存器压力、提高指令级并行（ILP）
- **可选**：不是后端必须的，但对性能影响大
- **适用**：对 in-order 处理器效果显著

## 调度框架三大组件

```
┌─────────────────────────────────────────────────────────────┐
│  1. ScheduleDAGInstrs (DDG 数据结构)                        │
│     表示指令依赖关系（数据依赖、内存依赖、控制依赖）          │
├─────────────────────────────────────────────────────────────┤
│  2. ScheduleDAGMutation (DDG 变异)                          │
│     修改依赖图（添加/移除约束）                              │
├─────────────────────────────────────────────────────────────┤
│  3. SchedulingStrategy (调度策略)                           │
│     决定指令选择顺序（启发式算法）                           │
└─────────────────────────────────────────────────────────────┘
```

## ScheduleDAGInstrs

### 依赖关系

```cpp
// 数据依赖 (RAW - Read After Write)
%add1 = add i32 %a, %b
%add2 = add i32 %add1, %c    // add2 依赖 add1

// 内存依赖
%v1 = load i32, i32* %ptr1
store i32 %val, i32* %ptr1   // store 可能影响 v1

// 反依赖 (WAR - Write After Read)
%v2 = load i32, i32* %ptr2
store i32 %val, i32* %ptr1   // 如果 ptr1 == ptr2，有 WAR
```

### 自定义 Mutation

```cpp
class MyMutation : public ScheduleDAGMutation {
  void apply(ScheduleDAGInstrs *DAG) override {
    // 修改依赖图
    for (SUnit &SU : DAG->SUnits) {
      // 添加/移除依赖边
    }
  }
};

// 注册 mutation
DAG->addMutation(std::make_unique<MyMutation>());
```

### 内置 Mutation

```cpp
// 内存操作聚类
DAG->addMutation(createLoadClusterDAGMutation());
DAG->addMutation(createStoreClusterDAGMutation());
```

## 调度策略

### 自定义策略

```cpp
class MySchedStrategy : public GenericScheduler {
public:
  MySchedStrategy(const MachineSchedContext *C) : GenericScheduler(C) {}

protected:
  bool tryCandidate(SchedCandidate &Cand, SchedCandidate &TryCand,
                    SchedBoundary *Zone) const override {
    bool BetterCand = GenericScheduler::tryCandidate(Cand, TryCand, Zone);
    
    // 自定义优先级逻辑
    if (TryCand.SU->getInstr()->getOpcode() == TargetOpcode::WIDENING_SMUL) {
      // 优先选择 widening multiply
      return true;
    }
    
    return BetterCand;
  }
};
```

### 注册策略

```cpp
class MyTargetPassConfig : public TargetPassConfig {
  ScheduleDAGInstrs *createMachineScheduler(MachineSchedContext *C) override {
    ScheduleDAGInstrs *DAG = new MyScheduleDAG(C);
    DAG->addMutation(std::make_unique<MyMutation>());
    return DAG;
  }
};
```

## 调度模型 (Scheduling Model)

### TableGen 描述

```tablegen
// 1. 定义处理单元
def ALURes : ProcResource<1>;      // 1 个 ALU 单元
def MemRes : ProcResource<1>;      // 1 个内存单元
def FPRes : ProcResource<1>;       // 1 个浮点单元

// 2. 定义调度事件
def WriteADD : SchedWrite;
def WriteMUL : SchedWrite;
def WriteLOAD : SchedWrite;
def ReadArg0 : SchedRead;
def ReadArg1 : SchedRead;

// 3. 绑定事件到资源
def : WriteRes<WriteADD, [ALURes]> {
  let Latency = 1;
}
def : WriteRes<WriteMUL, [ALURes]> {
  let Latency = 3;
}
def : WriteRes<WriteLOAD, [MemRes]> {
  let Latency = 4;
}

// 4. 装饰指令
def ADD32rr : Instruction {
  let SchedRW = [WriteADD, ReadArg0, ReadArg1];
}

// 5. 定义调度模型
def MySchedModel : SchedMachineModel {
  let IssueWidth = 4;           // 每周期最多发射 4 个微操作
  let MicroOpBufferSize = 128;  // 重排序缓冲区大小
  let LoadLatency = 4;          // 默认 load 延迟
}
```

### InstRW 绑定

```tablegen
// 方式 1：使用 InstRW（推荐）
let SchedModel = MySchedModel in {
  def : InstRW<[WriteADD], (instregex "ADD.*")>;
  def : InstRW<[WriteMUL], (instregex "MUL.*")>;
  def : InstRW<[WriteLOAD], (instregex "LD.*")>;
}

// 方式 2：使用 WriteRes + ReadAdvance
def : WriteRes<WriteWSMUL, [ALURes]> {
  let Latency = 2;
}
def : ReadAdvance<ReadWSMULArg0, 0>;      // 无转发
def : ReadAdvance<ReadWSMULArg1, 1>;      // 1 周期转发路径
```

### ProcessorModel

```tablegen
// 定义处理器模型
def : ProcessorModel<"my-cpu", MySchedModel, [Feature1, Feature2]>;

// 连接 Subtarget
def MySubtarget : SubtargetInfo {
  let CPU = "my-cpu";
}
```

## 调度算法

### 启发式策略

| 策略 | 说明 | 适用场景 |
|------|------|----------|
| **List Scheduling** | 贪心算法，每次选最高优先级 | 快速调度 |
| **Generic Scheduler** | 考虑资源约束和依赖 | 默认策略 |
| **Post-RA Scheduler** | 寄存器分配后调度 | 最终优化 |

### 优先级计算

```cpp
// 关键路径 (Critical Path)
int CriticalPath = SU.getDepth() + SU.getHeight();

// 资源压力 (Resource Pressure)
int ResourcePressure = countResourceConflicts(SU);

// 寄存器压力 (Register Pressure)
int RegPressure = estimateRegisterPressure(SU);
```

## 实践观察

### 实验 1：依赖链调度

**LLVM IR**:
```llvm
define i32 @chain(i32 %a, i32 %b, i32 %c) {
  %add1 = add i32 %a, %b
  %add2 = add i32 %add1, %c
  %add3 = add i32 %add2, %a
  ret i32 %add3
}
```

**NVPTX PTX** (严格顺序):
```ptx
add.s32 %r3, %r1, %r2;      // add1
add.s32 %r5, %r3, %r4;      // add2 (依赖 add1)
add.s32 %r6, %r3, %r5;      // add3 (依赖 add1, add2)
```

**x86_64 汇编** (使用 lea 优化):
```asm
leal (%rdi,%rsi), %ecx      # add1: a + b
leal (%rdx,%rcx), %eax      # add2: c + add1
addl %ecx, %eax             # add3: add1 + add2
```

**观察**：依赖链无法并行，调度器保持顺序。

### 实验 2：独立操作并行

**LLVM IR**:
```llvm
define i32 @parallel(i32 %a, i32 %b, i32 %c, i32 %d) {
  %add1 = add i32 %a, %b
  %add2 = add i32 %c, %d
  %sub1 = sub i32 %a, %c
  %sub2 = sub i32 %b, %d
  %mul1 = mul i32 %add1, %add2
  %add3 = add i32 %sub1, %sub2
  %result = add i32 %mul1, %add3
  ret i32 %result
}
```

**NVPTX PTX** (交错执行):
```ptx
add.s32 %r3, %r1, %r2;      # add1
add.s32 %r6, %r4, %r5;      # add2 (独立，可并行)
sub.s32 %r7, %r1, %r4;      # sub1
sub.s32 %r8, %r2, %r5;      # sub2
add.s32 %r9, %r7, %r8;      # add3
mad.lo.s32 %r10, %r3, %r6, %r9;  # mul1 + add3 融合
```

**x86_64 汇编** (优化调度):
```asm
leal (%rdi,%rsi), %r8d      # add1
leal (%rdx,%rcx), %eax      # add2 (独立)
imull %r8d, %eax            # mul1 (依赖 add1, add2)
subl %edx, %edi             # sub1
subl %ecx, %esi             # sub2
addl %esi, %eax             # add3 + mul1
addl %edi, %eax             # result
```

**观察**：
- 调度器将独立操作交错执行
- NVPTX 使用 `mad.lo.s32` 融合 mul+add
- x86_64 使用 `leal` 和 `imull` 优化依赖链

### 实验 3：内存操作调度

**LLVM IR**:
```llvm
define i32 @memory(i32* %ptr1, i32* %ptr2, i32 %val) {
  %v1 = load i32, i32* %ptr1
  %v2 = load i32, i32* %ptr2
  store i32 %val, i32* %ptr1
  %sum = add i32 %v1, %v2
  ret i32 %sum
}
```

**NVPTX PTX** (load 提前):
```ptx
ld.u32 %r1, [%rd1];         # load v1
ld.u32 %r2, [%rd2];         # load v2 (独立)
st.u32 [%rd1], %r3;         # store (延迟到最后)
add.s32 %r4, %r1, %r2;      # sum
```

**x86_64 汇编** (激进优化):
```asm
movl (%rdi), %eax           # load v1
addl (%rsi), %eax           # load v2 + add 融合
movl %edx, (%rdi)           # store (最后执行)
```

**观察**：
- 调度器将 load 提前（隐藏内存延迟）
- store 延迟到最后（减少内存依赖冲突）
- x86_64 甚至将 load+add 融合为单条指令

### 实验 4：浮点操作调度

**LLVM IR**:
```llvm
define float @float_ops(float %a, float %b, float %c) {
  %mul = fmul float %a, %b
  %add = fadd float %mul, %c
  %div = fdiv float %add, %a
  ret float %div
}
```

**NVPTX PTX** (顺序执行):
```ptx
mul.rn.f32 %f3, %f1, %f2;   # mul
add.rn.f32 %f5, %f3, %f4;   # add (依赖 mul)
div.rn.f32 %f6, %f5, %f1;   # div (依赖 add)
```

**x86_64 汇编** (SSE 指令):
```asm
mulss %xmm0, %xmm1          # mul
addss %xmm2, %xmm1          # add (依赖 mul)
divss %xmm0, %xmm1          # div (依赖 add)
```

**观察**：浮点操作有严格依赖链，无法并行。

## 调度模型实现建议

### 推荐方法

1. **使用 InstRW 而非 SchedWrite/SchedRead**
   - InstRW 局部于调度模型
   - SchedWrite/SchedRead 全局共享，难以维护

2. **逐步完善**
   - 先覆盖关键指令（load, store, mul, div）
   - 其余使用默认值（1 周期延迟）

3. **使用 ProcResGroup**
   - 将相关资源分组（如 MemAndALURes）
   - 简化绑定逻辑

### 实现步骤

```tablegen
// 1. 定义顶级调度模型
def MySchedModel : SchedMachineModel {
  let IssueWidth = 4;
  let MicroOpBufferSize = 128;
  let LoadLatency = 4;
}

// 2. 定义处理单元
def ALURes : ProcResource<1>;
def MemRes : ProcResource<1>;
def MemAndALURes : ProcResGroup<[MemRes, ALURes]>;

// 3. 定义调度事件
def WriteLoad : SchedWrite;
def WriteStore : SchedWrite;
def WriteALU : SchedWrite;

// 4. 绑定事件到资源
let SchedModel = MySchedModel in {
  let Latency = 4 in
  def : WriteRes<WriteLoad, [MemRes]>;
  
  let Latency = 1 in
  def : WriteRes<WriteALU, [ALURes]>;
}

// 5. 绑定到指令
let SchedModel = MySchedModel in {
  def : InstRW<[WriteLoad], (instregex "LD.*")>;
  def : InstRW<[WriteALU], (instregex "ADD.*,SUB.*,MUL.*")>;
}
```

## 调试调度

### 查看 DDG

```bash
# 图形化查看依赖图
llc -view-misched-dags test.ll

# 输出调度日志
llc -debug-only=misched test.ll 2>&1 | grep "Scheduling"
```

### 调度统计

```bash
# 查看调度统计
llc -stats test.ll 2>&1 | grep "sched"
```

## 关键收获

1. **调度是低级优化**：重新排列指令以提高 ILP
2. **DDG 表示依赖**：ScheduleDAGInstrs 管理依赖关系
3. **Mutation 修改依赖图**：添加/移除约束
4. **策略决定顺序**：GenericScheduler 提供启发式算法
5. **调度模型描述资源**：ProcResource, WriteRes, ReadAdvance
6. **InstRW 推荐**：局部绑定，易于维护
7. **load 提前 store 延迟**：隐藏内存延迟
8. **融合指令**：mad = mul + add，load+add 融合
9. **调试用 -view-misched-dags**：图形化查看依赖图

## 待探索

- [ ] 实现自定义 ScheduleDAGMutation
- [ ] 实现完整的调度模型（ProcResource + InstRW）
- [ ] 使用 -view-misched-dags 观察 DDG
