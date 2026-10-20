# LLVM 学习笔记

## 学习进度

### Chapter 1: Building LLVM and Understanding the Directory Structure
- **状态**: ✅ 已完成
- **日期**: 2026-09-05
- **笔记**: [Chapter 1 Notes](examples/part1_getting_started/ch01_building_llvm/README.md)
- **测验**: [Chapter 1 Quiz](examples/part1_getting_started/ch01_building_llvm/quiz.md)

**关键收获**:
1. LLVM 最初代表 Low-Level Virtual Machine，现在已成为编译器基础设施的代名词
2. LLVM 项目包含多个子项目：llvm（核心）、clang（C/C++前端）、lld（链接器）等
3. 核心目录结构：
   - `llvm/include/llvm/IR/` - LLVM IR 定义
   - `llvm/lib/Target/NVPTX/` - NVIDIA PTX 后端
   - `llvm/lib/Passes/` - 优化 Pass 实现
4. LLVM IR 有三种形式：文本(.ll)、二进制(.bc)、内存表示
5. 构建工具链：Git → CMake → Ninja → C/C++ Toolchain

---

### Chapter 3: Compiler Basics and How They Map to LLVM APIs
- **状态**: ✅ 已完成
- **日期**: 2026-09-05
- **笔记**: [Chapter 3 Notes](examples/part1_getting_started/ch03_compiler_basics/README.md)
- **测验**: [Chapter 3 Quiz](examples/part1_getting_started/ch03_compiler_basics/quiz.md)
- **探索脚本**: [explore_ir_structure.sh](examples/part1_getting_started/ch03_compiler_basics/explore_ir_structure.sh)

**关键收获**:
1. 编译器术语：Target, Host, Lowering, Canonical Form, ABI, Encoding
2. 四种基本结构：Module → Function → BasicBlock → Instruction
3. LLVM IR vs Machine IR 的关键差异（抽象级别、SSA、terminator 约束等）
4. CFG 核心概念：RPO 遍历、Backedge（循环识别）、Critical Edge（拆分优化）、Irreducible Graph
5. 在我们的编译链中：.cu/.ll/.bc 是 LLVM IR 级别，.ptx 是 Machine IR 级别，.cubin 是最终编码
6. LLVMContext 负责 uniquing；LLVM IR BasicBlock 必须有且仅有一个 terminator
7. 实践观察：O0 有 14 条指令，O2 优化后减少到 11 条

---

### Chapter 4: Writing Your First Optimization Pass
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 4 Notes](examples/part1_getting_started/ch04_first_optimization/README.md)
- **实践代码**: [const_fold_pass.cpp](examples/part1_getting_started/ch04_first_optimization/const_fold_pass.cpp)
- **扩展练习**: [const_fold_ext.cpp](examples/part1_getting_started/ch04_first_optimization/const_fold_ext.cpp)

**关键收获**:
1. **Pass 是 LLVM 编译流水线的构建块**，整个编译过程由一系列 Pass 组成
2. **Legacy Pass Manager 已在 LLVM 19 中完全移除**，必须使用 New Pass Manager 插件 API
3. **New Pass Manager 核心模式**：
   - Pass 类继承 `PassInfoMixin<YourPass>`，实现 `run()` 方法
   - 返回 `PreservedAnalyses::none()`（有修改）或 `PreservedAnalyses::all()`（无修改）
   - 通过 `llvmGetPassPluginInfo()` 导出 C 函数注册插件
4. **编译命令**：`clang++ -shared -fPIC -o Pass.so pass.cpp $(llvm-config --cxxflags --ldflags) -fno-rtti`
5. **运行命令**：`opt -load-pass-plugin ./Pass.so -passes="pass-name" < input.ll -S`
6. **实践验证**：
   - 基础版：支持 add/sub/mul，成功将 `2+3=5, 5*4=20, 20+10=30` 折叠为 `ret i32 30`
   - 扩展版：新增 shl/lshr/and/or/xor 支持，兼容 i8/i32/i64 等任意位宽
   - 与内置 `instcombine` 对比，效果一致
7. **调试技巧**：`-print-after-all` 可查看每个 Pass 后的 IR 变化

---

### Chapter 5: Dealing with Pass Managers
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 5 Notes](examples/part1_getting_started/ch05_pass_managers/README.md)
- **实践脚本**: [observe_pipeline.sh](examples/part1_getting_started/ch05_pass_managers/observe_pipeline.sh)
- **测试文件**: [test_pipeline.ll](examples/part1_getting_started/ch05_pass_managers/test_pipeline.ll)

**关键收获**:
1. **Pass Manager 是编译流水线的调度器**，负责 Pass 执行顺序、分析缓存、作用域切换
2. **New Pass Manager 使用按需计算 + 缓存机制**，分析结果在作用域内被复用，失效时自动重新计算
3. **`PreservedAnalyses` 精确描述 Pass 对分析的影响**，避免不必要的重新计算
4. **scope-preserving 结构**是推荐的流水线组织方式：IR 尽可能深地推入当前作用域
5. **关键调试工具**：
   - `-debug-pass-manager`: 显示 Pass 执行和分析计算日志
   - `-time-passes`: Pass 执行时间报告
   - `-print-after-all`: 每个 Pass 后打印 IR
   - `-print-pipeline-passes`: 导出 Pass 流水线列表
6. **O2 流水线包含 271 个 Pass**，InstCombine 占比最高（33%），是最核心的优化 Pass
7. **Legacy PM vs New PM**：Legacy 仍用于后端，中端已完全迁移到 New PM

---

### Chapter 6: TableGen – LLVM Swiss Army Knife for Modeling
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 6 Notes](examples/part1_getting_started/ch06_tablegen/README.md)
- **实践脚本**: [explore_tablegen.sh](examples/part1_getting_started/ch06_tablegen/explore_tablegen.sh)
- **实践文件**: [person.td](examples/part1_getting_started/ch06_tablegen/person.td), [multiclass_example.td](examples/part1_getting_started/ch06_tablegen/multiclass_example.td)

**关键收获**:
1. **TableGen 是 LLVM 的声明式建模语言**，将目标机器信息从 C++ 代码中解耦
2. **核心语法**：`class`（模板）、`def`（实例化）、`multiclass/defm`（批量生成）、`let`（字段覆盖）
3. **工作流程**：`.td` → `llvm-tblgen` → `.inc` → `#include` 到 LLVM 源码
4. **所有 LLVM 后端都依赖 TableGen** 描述寄存器、指令、特性、intrinsic 等
5. **NVPTX 实例**：用 `foreach` 批量生成 SM20~SM90 的 feature records，用 `SubtargetFeature` 描述 GPU 架构
6. **调试技巧**：先用 `llvm-tblgen file.td`（不带后端）验证前端，再启用具体后端

---

### Chapter 7: Understanding LLVM IR
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 7 Notes](examples/part2_middle_end/ch07_llvm_ir/README.md)
- **实践脚本**: [explore_ir.sh](examples/part2_middle_end/ch07_llvm_ir/explore_ir.sh)
- **实践文件**: [test_ir_basics.c](examples/part2_middle_end/ch07_llvm_ir/test_ir_basics.c)

**关键收获**:
1. **LLVM IR 四种结构层次**：Module → Function → BasicBlock → Instruction
2. **类型系统**：单值类型（整数/浮点/指针/向量）、label 类型、聚合类型（结构体/数组）
3. **SSA 形式**：每个值只被定义一次，phi 指令处理控制流合并点
4. **mem2reg 是关键 Pass**：将 O0 的 alloca/load/store 模式提升为 SSA 寄存器
5. **intrinsic 函数**：通用（`llvm.vector.reduce.add`）和目标特定（`llvm.nvvm.read.ptx.sreg.*`）
6. **LLVM IR 不是可移植格式**——triple、data layout、ABI 都是 target-specific
7. **bitcode 向后兼容，文本 IR 不保证**——版本迁移用 bitcode 做中间格式
8. **O2 优化效果**：代数化简、if-conversion（分支→select）、循环消除（闭式公式）、向量化
9. **隐式编号是陷阱**——手动编辑 IR 前先用 instnamer 命名所有变量

---

### Chapter 8: Survey of the Existing Passes
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 8 Notes](examples/part2_middle_end/ch08_existing_passes/README.md)
- **实践文件**: [test_passes.ll](examples/part2_middle_end/ch08_existing_passes/test_passes.ll)

**关键收获**:
1. **发现 Pass 的方法**：PassRegistry.def → 类名 → 源码文件
2. **三类 Pass**：辅助（verifier/printer）、规范化（instcombine/mem2reg/lcssa）、优化
3. **New PM CLI 支持嵌套作用域**：`function(...)`, `module(...)`, `loop(...)`
4. **Pass 组合产生协同效应**：`mem2reg + instcombine + simplifycfg` 可将 alloca 模式完全折叠为常量
5. **实践验证**：
   - `early-cse`: 消除重复的 `add i32 %a, %b`
   - `deadargelim`: 删除未使用的函数参数
   - `simplifycfg`: 合并块、消除不可达分支
   - `reassociate`: `(a+b+2)-b` → `a+2`
6. **TargetTransformInfo** 是目标相关优化的代价模型接口
7. **循环 Pass 自动保证 LCSSA 形式**

---

### Chapter 9: Introducing Target-Specific Constructs
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 9 Notes](examples/part2_middle_end/ch09_target_specific/README.md)
- **实践脚本**: [explore_target.sh](examples/part2_middle_end/ch09_target_specific/explore_target.sh)

**关键收获**:
1. **Target 信息流向**：TargetInfo → SubtargetInfo → TargetLowering → TTI → 优化 Pass
2. **Intrinsic 是桥梁**：连接源语言 → LLVM IR → 后端指令选择
3. **TTI (TargetTransformInfo) 控制优化方向**：成本模型决定向量化、循环展开等策略
4. **PassBuilder callbacks**：middle-end 注入点；**TargetPassConfig**：backend 注入点
5. **MC 层是汇编/机器码接口**：MCAsmInfo, MCSubtargetInfo, MCInstrInfo, MCRegisterInfo
6. **Data layout 编码 target 信息**：endian、对齐、原生整数宽度等
7. **NVPTX 注入 14 个自定义 Pass**：地址空间推断、NVVM 反射、参数/alloca 降级等
8. **不同 target 的自定义 Pass 差异巨大**：x86 有 23 个，AArch64 有 27 个

---

### Chapter 10: Hands-On Debugging LLVM IR Passes
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 10 Notes](examples/part2_middle_end/ch10_debugging/README.md)
- **实践脚本**: [debug_passes.sh](examples/part2_middle_end/ch10_debugging/debug_passes.sh)
- **测试文件**: [test_debug.ll](examples/part2_middle_end/ch10_debugging/test_debug.ll), [test_reduce.ll](examples/part2_middle_end/ch10_debugging/test_reduce.ll)

**关键收获**:
1. **IR 中间输出**：`-print-after-all` / `-print-before=<pass>` 跟踪每个 Pass 的效果
2. **opt-bisect-limit 是二分神器**：快速定位引入 bug 的具体 Pass
3. **llvm-reduce 自动缩减**：通过多轮迭代将测试用例缩减到最小（3 函数 → 1 声明）
4. **llvm-extract 提取子集**：自动处理依赖，提取函数/基本块为独立模块
5. **verify-each 保证正确性**：每个 Pass 后验证 IR 合法性
6. **dump() 方法 + LLDB**：在调试器中直接查看 LLVM 对象（需 assertions-enabled 构建）
7. **debug-only 需要 assertions-enabled**：系统 LLVM 通常不支持，需自行构建
8. **Sanitizers 深度排查**：address/memory/thread/undefined behavior 等运行时检测

---

### Chapter 11: Getting Started with the Backend
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 11 Notes](examples/part3_backend_intro/ch11_machine_ir/README.md)
- **实践脚本**: [observe_mir.sh](examples/part3_backend_intro/ch11_machine_ir/observe_mir.sh)
- **测试文件**: [test_simple.ll](examples/part3_backend_intro/ch11_machine_ir/test_simple.ll)

**关键收获**:
1. **Machine IR 是后端核心表示**：连接 LLVM IR 和最终汇编，支持 SSA + non-SSA
2. **MIR 使用 YAML 格式**：包含 LLVM IR + 寄存器声明 + 栈帧信息 + 指令体
3. **MachineInstr = 操作数数组 + MCInstrDesc 约束**：MCInstrDesc 定义操作数"契约"
4. **隐式操作数建模硬件/ABI 约束**：如 x86 eflags、调用约定寄存器
5. **Tied operands 打破 SSA**：读-写操作必须共享物理寄存器（如 x86 ADD）
6. **寄存器类定义可用寄存器集合**：NVPTX 有 int32regs，x86 有 gr32/gr64/fr32
7. **MC 层是汇编级抽象**：MCInst/MCOperand/MCInstrDesc 负责编码和反汇编
8. **TableGen 生成后端骨架**：gen-register-info, gen-instr-info, gen-subtarget
9. **llc 控制 Pass 范围**：`-start-after`, `-stop-after`, `-run-pass` 精确定位

---

### Chapter 12: Getting Started with the Machine Code Layer
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 12 Notes](examples/part3_backend_intro/ch12_mc_layer/README.md)
- **实践脚本**: [explore_mc.sh](examples/part3_backend_intro/ch12_mc_layer/explore_mc.sh)

**关键收获**:
1. **MC 层是汇编级抽象**：MCInst ↔ 汇编文本 ↔ 字节编码
2. **TableGen 生成大部分 MC 代码**：printInstruction, getBinaryCodeForInstr
3. **编码族分组很重要**：提前规划 TableGen 类层次结构（ALU/Mem/Branch 等）
4. **MCInstPrinter 负责反汇编**：MCInst → 汇编文本
5. **MCCodeEmitter 负责编码**：MCInst → 字节序列
6. **MCAsmParser 最复杂**：汇编文本 → MCInst，需大量手动实现
7. **llvm-mc 是测试利器**：`-show-encoding` 验证汇编编码，`-disassemble` 验证反汇编
8. **不是所有指令都需要编码**：伪指令（PHI, COPY）仅存在于 Machine 层

---

### Chapter 13: The Machine Pass Pipeline
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 13 Notes](examples/part3_backend_intro/ch13_machine_pass_pipeline/README.md)
- **实践脚本**: [observe_pipeline.sh](examples/part3_backend_intro/ch13_machine_pass_pipeline/observe_pipeline.sh)

**关键收获**:
1. **Machine Pipeline 分 5 大阶段**：Pre-ISel → ISel → Post-ISel Pre-RA → RA → Post-RA
2. **IR 从 SSA 降级到 non-SSA**：寄存器分配是关键转折点
3. **TargetPassConfig 提供 6+ 注入点**：addPreISel, addPreRegAlloc, addPreEmitPass 等
4. **不要重写 addMachinePasses()**：使用注入点方法添加自定义 Pass
5. **通用 Pass 依赖 Target 信息**：TargetLowering, TargetInstrInfo, TargetRegisterInfo
6. **CodeGenPrepare 优化地址模式**：通过 isLegalAddressingMode 控制
7. **PeepholeOptimizer vs MachineCombiner**：前者目标无关，后者目标相关
8. **查看 getRequiredProperties()**：了解 Pass 对 IR 属性的约束

---

### Chapter 14: Getting Started with Instruction Selection
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 14 Notes](examples/part4_instruction_selection/ch14_isel_intro/README.md)
- **实践脚本**: [observe_isel.sh](examples/part4_instruction_selection/ch14_isel_intro/observe_isel.sh)
- **测试文件**: [test_isel.ll](examples/part4_instruction_selection/ch14_isel_intro/test_isel.ll)

**关键收获**:
1. **三种指令选择框架**：FastISel（快）、SDISel（好）、GlobalISel（新，模块化）
2. **指令选择三阶段**：IR Building → Legalization → Selection
3. **SelectionDAG 是 SDISel 核心**：SDNode（操作）+ SDValue（输出值）
4. **GlobalISel 使用 Generic MIR**：G_ADD, G_MUL 等通用操作码
5. **TableGen 生成选择代码**：-gen-dag-isel, -gen-fast-isel, -gen-global-isel
6. **融合指令是优化关键**：mul+add → mad (NVPTX), lea 替代 add (x86)
7. **AsmPrinter 连接 MC 层**：MachineInstr → MCInst → 汇编
8. **TargetPassConfig 注入 Pass**：addInstSelector, addLegalizeMachineIR 等
9. **新项目推荐 GlobalISel**：可测试性好，架构现代

---

### Chapter 15: Instruction Selection: The IR Building Phase
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 15 Notes](examples/part4_instruction_selection/ch15_isel_ir_building/README.md)
- **实践脚本**: [observe_abi.sh](examples/part4_instruction_selection/ch15_isel_ir_building/observe_abi.sh)
- **测试文件**: [test_abi.ll](examples/part4_instruction_selection/ch15_isel_ir_building/test_abi.ll)

**关键收获**:
1. **IR Building 两阶段**：纯 IR 转换 + ABI Lowering（调用约定实现）
2. **调用约定是核心**：参数传递、返回值、callee-saved 寄存器
3. **TableGen 描述调用约定**：CallingConv, CCAction, CalleeSavedRegs
4. **SDISel 三个方法**：LowerFormalArguments, LowerCall, LowerReturn
5. **GlobalISel 更模块化**：CallLowering + Assigner + Handler
6. **CCState 管理状态**：CCValAssign 记录每个参数的位置（寄存器/栈）
7. **sret 降级大返回值**：结构体返回通过指针参数
8. **callseq 标记调用边界**：确定栈帧大小
9. **不同 ABI 差异巨大**：NVPTX 用参数内存（.param），x86_64 用寄存器传参

---

### Chapter 16: Instruction Selection: The Legalization Phase
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 16 Notes](examples/part4_instruction_selection/ch16_isel_legalization/README.md)
- **实践脚本**: [observe_legalize.sh](examples/part4_instruction_selection/ch16_isel_legalization/observe_legalize.sh)
- **测试文件**: [test_legalize.ll](examples/part4_instruction_selection/ch16_isel_legalization/test_legalize.ll)

**关键收获**:
1. **Legalization 两阶段**：类型合法化 → 操作合法化
2. **SDISel 依赖 Legal Types**：标记合法类型，其余自动处理
3. **GlobalISel 无 Legal Types**：使用程序化规则（LegalizeRuleSet）精确描述
4. **9 种合法化动作**：Legal, Promote, Expand, Soften, Scalarize, Split, Widen, LibCall, Custom
5. **类型提升示例**：i8 → i16 加法 → i32 转换（NVPTX），i8 在 32 位寄存器中操作（x86_64）
6. **i64 拆分**：NVPTX 将 i64 拆为两个 i32，使用 addc（带进位加）
7. **向量合法化复杂**：<3 x i8> 打包到 32 位寄存器，使用 SIMD 指令
8. **浮点操作常需 LibCall**：目标不支持时回退到库函数
9. **自定义合法化是高级手段**：SDISel 用 LowerOperation，GlobalISel 用 legalizeCustom

---

### Chapter 17: Instruction Selection: The Selection Phase and Beyond
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 17 Notes](examples/part4_instruction_selection/ch17_isel_selection/README.md)
- **实践脚本**: [observe_selection.sh](examples/part4_instruction_selection/ch17_isel_selection/observe_selection.sh)
- **测试文件**: [test_selection.ll](examples/part4_instruction_selection/ch17_isel_selection/test_selection.ll)

**关键收获**:
1. **Selection Phase 是最后阶段**：Generic IR → Target-Specific MachineInstr
2. **TableGen 模式是核心**：声明式描述指令匹配（Pat, ComplexPattern, SDNodeXForm）
3. **RegBankSelect 优化拷贝**：减少跨寄存器库转换（GPR↔FPR）
4. **Custom Inserter 展开伪指令**：处理复杂代码序列（usesCustomInserter = true）
5. **DAG Combine 优化**：mul+add → mad 融合，地址模式优化
6. **FinalizeISel 清理**：冻结保留寄存器，准备后续 Pass
7. **调试用 -debug-only=isel**：查看模式匹配过程和 match table
8. **SIMD 选择差异大**：x86 用 paddd（真 SIMD），NVPTX 标量化为 4 个标量加法
9. **复杂地址模式**：x86 用 (base,idx,scale)，NVPTX 显式计算（mul.wide + add）

---

### Chapter 18: Instruction Scheduling
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 18 Notes](examples/part5_final_lowering/ch18_scheduling/README.md)
- **实践脚本**: [observe_schedule.sh](examples/part5_final_lowering/ch18_scheduling/observe_schedule.sh)
- **测试文件**: [test_schedule.ll](examples/part5_final_lowering/ch18_scheduling/test_schedule.ll)

**关键收获**:
1. **调度是低级优化**：重新排列指令以提高 ILP（指令级并行）
2. **DDG 表示依赖**：ScheduleDAGInstrs 管理数据依赖、内存依赖、控制依赖
3. **Mutation 修改依赖图**：添加/移除约束（如内存操作聚类）
4. **策略决定顺序**：GenericScheduler 提供启发式算法，可自定义优先级
5. **调度模型描述资源**：ProcResource（处理单元）、WriteRes（写延迟）、ReadAdvance（转发路径）
6. **InstRW 推荐**：局部绑定，易于维护，避免全局 SchedWrite/SchedRead
7. **load 提前 store 延迟**：隐藏内存访问延迟，减少依赖冲突
8. **指令融合**：mul+add → mad，load+add → 单条指令
9. **调试用 -view-misched-dags**：图形化查看依赖图

---

### Chapter 19: Register Allocation
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 19 Notes](examples/part5_final_lowering/ch19_regalloc/README.md)
- **实践脚本**: [observe_regalloc.sh](examples/part5_final_lowering/ch19_regalloc/observe_regalloc.sh)
- **测试文件**: [test_regalloc.ll](examples/part5_final_lowering/ch19_regalloc/test_regalloc.ll)

**关键收获**:
1. **目标只需实现 spill hook**：storeRegToStackSlot, loadRegFromStackSlot
2. **Slot Index 唯一标识指令**：编号 + 阶段（B/E/R/D）
3. **Live Interval 保持 SSA**：即使 Machine IR 非 SSA，仍用 VNInfo 追踪定义
4. **VNInfo 记录定义**：支持到达定义分析，phi 节点标记为 `-phi`
5. **寄存器合并减少 COPY**：Coalescer 在分配前运行
6. **常量折叠优化**：1+2+...+10 → 55（单条指令）
7. **Phi 消除**：通过分支或条件移动实现
8. **NVPTX 寄存器多**：11 个虚拟寄存器无 spill
9. **x86_64 寄存器少**：高效分配 6 个物理寄存器

---

### Chapter 20: Lowering of the Stack Layout
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 20 Notes](examples/part5_final_lowering/ch20_stack_layout/README.md)
- **实践脚本**: [observe_stack.sh](examples/part5_final_lowering/ch20_stack_layout/observe_stack.sh)
- **测试文件**: [test_stack.ll](examples/part5_final_lowering/ch20_stack_layout/test_stack.ll)

**关键收获**:
1. **栈布局三要素**：TargetFrameLowering、TargetRegisterInfo、PEI
2. **Prologue/Epilogue**：分配/释放栈空间（subq/addq 栈指针）
3. **Frame Index 展开**：替换为 SP + offset
4. **寄存器争夺**：RegScavenger 查找可用寄存器
5. **Emergency Spill Slot**：无寄存器时溢出到栈
6. **x86_64 栈向下增长**：subq 分配，addq 释放
7. **NVPTX 无显式栈**：使用参数内存和寄存器
8. **优化器消除冗余**：常量折叠、寄存器提升

---

### Chapter 21: Getting Started with the Assembler
- **状态**: ✅ 已完成
- **日期**: 2026-10-20
- **笔记**: [Chapter 21 Notes](examples/part5_final_lowering/ch21_assembler/README.md)
- **实践脚本**: [observe_assembler.sh](examples/part5_final_lowering/ch21_assembler/observe_assembler.sh)
- **测试文件**: [test_assembler.ll](examples/part5_final_lowering/ch21_assembler/test_assembler.ll)

**关键收获**:
1. **Assembler 是编译器后端与二进制工具的边界**
2. **三步流程**：解析 → 编码 → 写入
3. **Fixup 是未解析的地址引用**：编码时填入占位符
4. **重定位记录符号引用**：链接器解析最终地址
5. **MCAsmBackend 处理 fixup 和松弛**
6. **MCCodeEmitter 编码指令为二进制**
7. **MCObjectTargetWriter 生成特定格式重定位**
8. **外部符号产生重定位**：callq func@PLT → R_X86_64_PLT32

---

## 环境信息

- **GPU**: NVIDIA GeForce RTX 4090 D (sm_89)
- **Driver**: 580.126.09
- **CUDA**: 13.0 (V13.0.48)
- **LLVM**: 19.1.7
- **Clang**: 19.1.7

## 编译链命令

```bash
# 完整流程
.cu → .ll → .bc → .ptx → .cubin

# 具体命令
clang -x cuda --cuda-gpu-arch=sm_89 --cuda-device-only -S -emit-llvm test.cu -o test.ll
llvm-as test.ll -o test.bc
llc test.bc -march=nvptx64 -mcpu=sm_89 -filetype=asm -o test.ptx
ptxas test.ptx -arch=sm_89 -o test.cubin
```

## 重要概念

### 编译器三层架构
1. **前端 (Frontend)**: 源代码 → LLVM IR
2. **中端 (Middle-end)**: 优化 LLVM IR
3. **后端 (Backend)**: LLVM IR → 机器码

### LLVM IR vs Machine IR
- **LLVM IR**: 目标无关，高级抽象，SSA 形式
- **Machine IR**: 目标相关，引入寄存器和机器指令

### 关键工具
- `clang`: C/C++/CUDA 前端编译器
- `opt`: LLVM IR 优化器
- `llc`: 后端代码生成器
- `llvm-as/llvm-dis`: IR 汇编/反汇编
- `llvm-extract`: 提取函数/基本块
- `llvm-reduce`: 自动缩减测试用例
- `bugpoint`: 传统缩减工具（LLVM 19 仍可用）

## 学习资源

- **书籍**: LLVM Code Generation (2025) by Quentin Colombet
- **官方文档**: https://llvm.org/docs/
- **NVPTX 后端**: https://llvm.org/docs/NVPTXUsage.html
- **书籍代码**: https://github.com/PacktPublishing/LLVM-Code-Generation

## 待探索问题

1. NVPTX 后端如何处理 GPU 特有的概念（warp、shared memory）？
2. ~~LLVM IR 中的 `llvm.nvvm.*` intrinsics 是什么？~~ → 已部分解答：它们是读取 GPU 特殊寄存器的内置函数（ctaid.x=blockIdx, tid.x=threadIdx, ntid.x=blockDim）
3. PTX 和 SASS 之间有什么关系？
4. 如何编写自定义的优化 Pass？ → ✅ 已在 Chapter 4 中完成：使用 New Pass Manager 插件 API，继承 PassInfoMixin，通过 llvmGetPassPluginInfo() 注册
5. TableGen 是如何描述目标机器特性的？ → ✅ 已在 Chapter 6 中完成：通过 .td 文件中的 class/def/multiclass 定义寄存器、指令、特性等，由 llvm-tblgen 生成 .inc C++ 代码

## 学习笔记模板

### Chapter X: [标题]

**日期**: YYYY-MM-DD

**主要内容**:
- 

**关键概念**:
- 

**代码示例**:
```
```

**问题和思考**:
- 

**练习**:
- [ ] 
