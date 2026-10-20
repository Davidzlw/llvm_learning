# Chapter 8: Survey of the Existing Passes

## 学习目标

完成本章后，你将能够：
- 掌握发现和分析未知 Pass 的方法论
- 理解 LLVM 中端的主要 Pass 分类和各自功能
- 使用 `opt` 工具运行和观察各种 Pass 的效果
- 理解 New Pass Manager CLI 的嵌套流水线语法

---

## 8.1 如何发现未知 Pass

### 方法论

```bash
# 1. 列出所有注册的 passes (按作用域分类)
opt --passes="help"  # 或通过 -debug-pass-manager 观察

# 2. 查找 pass 源码位置
git grep "pass-name" llvm/lib/Passes/PassRegistry.def
# 例: git grep "always-inline" → MODULE_PASS("always-inline", AlwaysInlinerPass())

# 3. 通过类名查找实现
git grep -l "class AlwaysInlinerPass" llvm

# 4. 查看 pass 描述
opt --help | grep "pass-name"
```

### New Pass Manager CLI 语法

```bash
# 默认作用域（由第一个 pass 决定）
opt -passes=mypass input.ll

# 显式指定作用域
opt -passes="function(passA,passB)" input.ll    # 函数级
opt -passes="module(passA,passB)" input.ll      # 模块级
opt -passes="loop(passA,passB)" input.ll        # 循环级

# 嵌套流水线
opt -passes="function(mem2reg,instcombine),globaldce" input.ll

# 带参数
opt -passes="instcombine<use-loop-info;max-iterations=3>" input.ll
```

---

## 8.2 辅助 Pass

### Verifier（验证器）

验证 IR 的合法性，**任何 IR 问题首先运行它**：

```bash
opt -passes=verify < input.ll -S
```

### Printer（打印器）

```bash
# 每个 pass 后打印 IR
opt -passes=mypass -print-after-all < input.ll -S

# 指定 pass 前后打印
opt -passes=mypass -print-before=instcombine < input.ll -S

# 打印循环信息
opt -passes="print<loops>" < input.ll -o /dev/null
```

---

## 8.3 规范化 Pass（Canonical Passes）

这些 Pass 建立标准 IR 形式，是后续优化的前提：

| Pass | CLI 名称 | 功能 |
|------|---------|------|
| InstCombine | `instcombine` | 指令合并：模式匹配 + 代数化简 |
| Mem2Reg | `mem2reg` | 将 alloca 提升为 SSA 寄存器 |
| LCSSA | `lcssa` | 循环闭合 SSA 形式 |

### instcombine 详解

两类重写：
1. **规范化**：将等价但不同的 IR 形式统一（如 `trunc(zext(x))` → `x`）
2. **优化**：识别通用模式并简化（如 `xor %x, %x` → `0`）

```llvm
; 输入
%xor = xor i64 %x, %x    ; 任何值 XOR 自身 = 0

; instcombine 输出
; 所有 %xor 的使用被替换为 0
```

### mem2reg 详解

将 alloca/load/store 模式转换为 SSA 形式：
- 消除不必要的内存访问
- 在控制流合并点插入 phi 指令
- 提供 SSA 的 def-use 链和支配性质

### LCSSA 详解

为循环创建闭合 SSA 形式：
- 循环内定义的值如果在循环外使用，通过额外的 phi 节点中转
- 简化循环内/外使用的区分
- Loop pass 自动保证 LCSSA 形式

---

## 8.4 优化 Pass 分类

### IPO（跨过程优化）

| Pass | CLI | 功能 |
|------|-----|------|
| AlwaysInliner | `always-inline` | 内联 alwaysinline 函数 |
| DeadArgElim | `deadargelim` | 删除未使用的函数参数 |
| GlobalOpt | `globalopt` | 全局变量优化 |
| GlobalDCE | `globaldce` | 删除未引用的全局定义 |
| IPSCCP | `ipsccp` | 跨过程常量传播 |
| FunctionAttrs | `function-attrs` | 推导函数属性（readonly 等） |

### Scalar（标量优化）

| Pass | CLI | 功能 |
|------|-----|------|
| EarlyCSE | `early-cse` | 公共子表达式消除 |
| SROA | `sroa` | 标量替换聚合 |
| GVN | `gvn` | 全局值编号 |
| ADCE | `adce` | 聚合死代码消除 |
| DSE | `dse` | 死存储消除 |
| JumpThreading | `jumpthreading` | 跳转线程 |
| SimplifyCFG | `simplifycfg` | CFG 简化 |
| Reassociate | `reassociate` | 重新结合（代数化简） |
| CorrelatedValuePropagation | `correlated-value-propagation` | 关联值传播 |

### Loop（循环优化）

| Pass | CLI | 功能 |
|------|-----|------|
| LICM | `licm` | 循环不变量外提 |
| LoopStrengthReduce | `loop-reduce` | 循环强度削减 |
| LoopUnroll | `loop-unroll` | 循环展开 |
| IndVarSimplify | `indvars` | 归纳变量简化 |

### Vectorize（向量化）

| Pass | CLI | 功能 |
|------|-----|------|
| LoadStoreVectorizer | `load-store-vectorizer` | 合并连续 load/store |
| SLPVectorizer | `slp-vectorizer` | 超字级并行向量化 |
| LoopVectorize | `loop-vectorize` | 循环向量化 |

---

## 8.5 分析 Pass

| 分析 | 获取方式 (New PM) | 功能 |
|------|-------------------|------|
| TargetTransformInfo | `FAM.getResult<TargetIRAnalysis>(F)` | 目标变换代价信息 |
| LoopInfo | `FAM.getResult<LoopAnalysis>(F)` | 循环嵌套结构 |
| AliasAnalysis | 多个分析组合 | 指针别名关系 |
| DominatorTree | `FAM.getResult<DominatorTreeAnalysis>(F)` | 支配树 |

---

## 8.6 实践观察

### deadargelim: 删除死参数

```llvm
; 输入
define internal i32 @bar(ptr %local, ptr %local2) {
  %val = load i64, ptr %local
  ret i64 %val          ; %local2 从未使用
}

; 输出
define internal i32 @bar(ptr %local) {
  %val = load i64, ptr %local
  ret i64 %val
}
```

### early-cse: 公共子表达式消除

```llvm
; 输入
%x = add i32 %a, %b
%y = add i32 %a, %b    ; 与 %x 相同
%z = mul i32 %x, %y

; 输出
%x = add i32 %a, %b
%z = mul i32 %x, %x    ; %y 被消除，直接用 %x
```

### simplifycfg: CFG 简化

```llvm
; 输入
define i32 @foo(i32 %x) {
entry:
  br label %next
next:
  br i1 false, label %a, label %b   ; 常量条件
a:
  ret i32 1
b:
  ret i32 %x
}

; 输出 (合并所有块，消除不可达分支)
define i32 @foo(i32 %x) {
entry:
  ret i32 %x
}
```

### reassociate: 代数化简

```llvm
; 输入
%v0 = add i32 %a, %b
%v1 = add i32 %v0, 2
%v2 = sub i32 %v1, %b    ; (a+b+2)-b

; 输出
%v2 = add i32 %a, 2       ; 直接 a+2
```

### 组合流水线效果

```bash
opt -passes="mem2reg,instcombine,simplifycfg" < test.ll -S
```

sroa_test: alloca(10) + alloca(20) + load + add → `ret i32 30`（完全折叠）

### 循环信息打印

```bash
opt -passes="print<loops>" < test.ll -o /dev/null
```

输出：`Loop at depth 1 containing: %loop<header><latch><exiting>`

---

## 8.7 核心收获

1. **不要重复造轮子**：在写新 Pass 前，先检查 LLVM 是否已有实现
2. **发现 Pass 的方法**：PassRegistry.def → 类名 → 源码文件
3. **三类 Pass**：辅助（verifier/printer）、规范化（instcombine/mem2reg/lcssa）、优化
4. **New PM CLI 支持嵌套作用域**：`function(...)`, `module(...)`, `loop(...)`
5. **Pass 组合很重要**：单独 Pass 效果有限，组合使用能产生协同效应
6. **TargetTransformInfo** 是目标相关优化的关键接口（代价模型）
7. **循环 Pass 自动保证 LCSSA 形式**

---

## 8.8 参考资源

- New PM CLI: https://llvm.org/docs/NewPassManager.html#invoking-opt
- Pass 注册表: `llvm/lib/Passes/PassRegistry.def`
- 下一章: Chapter 9 - Introducing Target-Specific Constructs
