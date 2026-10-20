# Chapter 5: Dealing with Pass Managers

## 学习目标

完成本章后，你将能够：
- ✅ 理解 Pass 和 Pass Manager 的概念与关系
- ✅ 区分 Legacy Pass Manager 和 New Pass Manager
- ✅ 使用 `opt` 工具构建和观察 Pass 流水线
- ✅ 解读 Pass 流水线结构日志和时间分析报告
- ✅ 理解分析 Pass 的缓存与失效机制

---

## 5.1 什么是 Pass Manager？

### 概念

**Pass Manager** 是驱动 Pass 执行的框架。它负责：
1. **调度** Pass 的执行顺序
2. **管理** 分析 Pass 的缓存和失效
3. **处理** 不同作用域（Module/Function/Loop）之间的切换

> Pass 是"做什么"，Pass Manager 是"怎么调度"。

### 两种 Pass Manager

| 特性 | Legacy PM | New PM |
|------|-----------|--------|
| 状态 | LLVM 19 中仍用于后端 | 中端（`opt`）已完全迁移 |
| Pass 基类 | `FunctionPass`, `ModulePass` | `PassInfoMixin<YourPass>` |
| 依赖声明 | `addRequired<Analysis>()` | 按需自动计算 |
| 分析失效 | 隐式（`getAnalysisUsage`） | 显式（`PreservedAnalyses`） |
| 日志能力 | `-debug-pass=Structure` | `-debug-pass-manager` |
| 插件方式 | `RegisterPass<X>` | `PassPlugin` API |

> **重点**: 本章聚焦 New Pass Manager，因为它是现代 LLVM 开发的标准。

---

## 5.2 New Pass Manager 核心机制

### 5.2.1 Pass 的作用域

Pass 只能在特定作用域内修改 IR：

| 作用域 | 方法签名 |
|--------|---------|
| Module | `Result run(Module &M, ModuleAnalysisManager &AM)` |
| Function | `Result run(Function &F, FunctionAnalysisManager &FAM)` |
| Loop | `Result run(Loop &L, LoopAnalysisManager &AM, ...)` |
| CGSCC | `Result run(LazyCallGraph::SCC &C, CGSCCAnalysisManager &AM, ...)` |

### 5.2.2 分析缓存机制

New Pass Manager 的核心创新是 **按需计算 + 缓存** 分析结果：

```
Pass A 需要 DominatorTree
  → Pass Manager 检查缓存
    → 缓存命中 → 直接返回
    → 缓存失效 → 重新计算 → 存入缓存
```

Pass 通过返回 `PreservedAnalyses` 告知哪些分析仍然有效：
- `PreservedAnalyses::all()` — IR 未修改，所有分析保留
- `PreservedAnalyses::none()` — IR 已修改，所有分析失效
- `PA.preserve<MyAnalysis>()` — 精确保留特定分析

### 5.2.3 作用域推进规则

Pass Manager 会将 IR **尽可能深地推入当前作用域**：

```
推荐结构（scope-preserving）:
  FunctionPassA → foo
  FunctionPassB → foo
  FunctionPassA → bar
  FunctionPassB → bar
  ModulePassC → [module]

非推荐结构:
  FunctionPassA → foo
  FunctionPassA → bar
  FunctionPassB → foo
  FunctionPassB → bar
  ModulePassC → [module]
```

---

## 5.3 实践：观察 Pass 流水线

### 5.3.1 测试文件

创建 `test_pipeline.ll`，包含三种可优化模式：
- `alloca/load/store` → mem2reg 可提升为 SSA
- 常量表达式 → instcombine 可折叠
- `alwaysinline` 函数 → inliner 可内联

### 5.3.2 逐步运行 Pass

```bash
# 仅运行 mem2reg：消除 alloca
opt -passes=mem2reg < test_pipeline.ll -S

# 运行 mem2reg + instcombine
opt -passes="mem2reg,instcombine" < test_pipeline.ll -S

# 运行完整 O2 流水线
opt -passes="default<O2>" < test_pipeline.ll -S
```

**观察结果**：

| Pass 组合 | main_test 结果 | pure_const 结果 |
|-----------|---------------|----------------|
| 原始 IR | 12 条指令（含 alloca） | 4 条指令 |
| +mem2reg | 消除 %y，简化 load | 不变 |
| +instcombine | `mul→shl`，常量折叠 340 | 折叠为 `ret i32 22` |
| default\<O2\> | 完全折叠为 `ret i32 424` | 完全折叠为 `ret i32 22` |

### 5.3.3 观察 Pass 流水线结构

使用 `-debug-pass-manager` 查看每个 Pass 的执行和分析计算：

```bash
opt -passes="mem2reg,instcombine" -debug-pass-manager < test_pipeline.ll -o /dev/null
```

输出示例：
```
Running pass: PromotePass on helper (2 instructions)
Running analysis: DominatorTreeAnalysis on helper
Running analysis: AssumptionAnalysis on helper
Running pass: InstCombinePass on helper (2 instructions)
Running analysis: TargetLibraryAnalysis on helper
Running analysis: AAManager on helper
Running pass: PromotePass on main_test (12 instructions)
Running analysis: DominatorTreeAnalysis on main_test
...
```

**关键观察**：
1. 每个函数依次通过所有 function passes（scope-preserving）
2. 分析 Pass 按需计算（DominatorTree, AA 等）
3. 分析结果在同一作用域内被缓存复用

### 5.3.4 查看 IR 变化

使用 `-print-after-all` 查看每个 Pass 后的 IR：

```bash
opt -passes="mem2reg,instcombine" -print-after-all < test_pipeline.ll -S
```

关键变化：
```llvm
; InstCombinePass on main_test:
; 之前: %c = add i32 %a, 20; %d = mul i32 %c, 2; %e = add i32 100, 200
; 之后:  %c = shl i32 %a, 1; %f = add i32 %c, 340
```

### 5.3.5 时间分析报告

使用 `-time-passes` 查看各 Pass 耗时：

```bash
opt -passes="mem2reg,instcombine" -time-passes < test_pipeline.ll -o /dev/null
```

输出：
```
Pass execution timing report
  Total Execution Time: 0.0003 seconds

  --- Name ---
  InstCombinePass    (45.0%)  ← 最耗时的优化 Pass
  PromotePass        ( 7.5%)
  VerifierPass       ( 2.8%)
```

### 5.3.6 查看流水线 Pass 列表

使用 `-print-pipeline-passes` 导出可复现的 Pass 列表：

```bash
opt -passes="mem2reg,instcombine" -print-pipeline-passes < test_pipeline.ll -o /dev/null
# 输出: function(mem2reg,instcombine<max-iterations=1;...>),verify,BitcodeWriterPass
```

---

## 5.4 O2 流水线全景

运行 `default<O2>` 时，共执行 **271 个 Pass**，主要耗时 Pass：

| Pass | 耗时占比 | 功能 |
|------|---------|------|
| InstCombinePass | 33.0% | 指令合并与常量折叠 |
| EarlyCSEPass | 10.8% | 早期公共子表达式消除 |
| AlwaysInlinerPass | 8.1% | 内联 alwaysinline 函数 |
| SROAPass | 6.7% | 标量替换聚合 |
| SimplifyCFGPass | 4.5% | 简化控制流图 |
| IPSCCPPass | 3.7% | 跨过程常量传播 |

---

## 5.5 调试技巧总结

| 选项 | 用途 |
|------|------|
| `-print-after-all` | 每个 Pass 后打印 IR |
| `-print-before-all` | 每个 Pass 前打印 IR |
| `-print-after=PASSNAME` | 指定 Pass 后打印 IR |
| `-debug-pass-manager` | 显示 Pass 执行和分析计算日志 |
| `-time-passes` | Pass 执行时间报告 |
| `-print-pipeline-passes` | 导出 Pass 流水线列表 |
| `-verify-each` | 每个 Pass 后验证 IR 合法性 |

---

## 5.6 核心收获

1. **Pass Manager 是编译流水线的调度器**，负责 Pass 执行顺序、分析缓存、作用域切换
2. **New Pass Manager 使用按需计算 + 缓存**，比 Legacy PM 更高效
3. **`PreservedAnalyses` 精确描述 Pass 对分析的影响**，避免不必要的重新计算
4. **scope-preserving 结构**是推荐的流水线组织方式（IR 尽可能深地推入当前作用域）
5. **`-debug-pass-manager`** 是理解流水线行为的最强工具
6. **O2 流水线包含 271 个 Pass**，InstCombine 是最核心也最耗时的优化 Pass

---

## 5.7 参考资源

- New Pass Manager 文档: https://llvm.org/docs/NewPassManager.html
- Pass 插件示例: https://llvm.org/docs/WritingAnLLVMPlugin.html
- `opt` 工具: https://llvm.org/docs/CommandGuide/opt.html
- 下一章: Chapter 6 - TableGen
