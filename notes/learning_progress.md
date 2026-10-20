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
