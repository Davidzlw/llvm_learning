# Chapter 10: Hands-On Debugging LLVM IR Passes

## 概述

本章介绍 LLVM 提供的调试工具和技术，用于排查 Pass 流水线中的问题：
- 日志机制（IR dump、debug log、statistics）
- 测试用例缩减（llvm-extract、llvm-reduce、bugpoint）
- Sanitizers（内存泄漏、未定义行为检测）
- LLDB 调试器交互

## 调试工具分类

### 1. IR 中间输出（Intermediate Dumps）

| 选项 | 说明 |
|------|------|
| `-print-after-all` | 每个 Pass 后打印 IR |
| `-print-before-all` | 每个 Pass 前打印 IR |
| `-print-after=Pass1,Pass2` | 指定 Pass 后打印 |
| `-print-before=Pass1` | 指定 Pass 前打印 |

**典型调试流程**：
1. 用 `-print-after-all` 找到引入问题的 Pass
2. 提取该 Pass 的输入 IR
3. 单独运行该 Pass 观察变化

### 2. Debug Log（调试日志）

```bash
# 需要 assertions-enabled 的 LLVM 构建
opt -passes="instcombine" -debug-only=instcombine input.ll -S

# 查看所有 Pass 的日志（输出巨大）
opt -passes="instcombine" -debug input.ll -S
```

**在自定义 Pass 中添加日志**：
```cpp
#define DEBUG_TYPE "mypass"
#include "llvm/Support/Debug.h"

// 在 run() 方法中
LLVM_DEBUG(dbgs() << "Processing: " << Inst << "\n");
```

### 3. Statistics（统计信息）

```bash
opt -passes="instcombine" -stats input.ll -S 2>&1 | grep "instcombine"
```

**在自定义 Pass 中添加统计**：
```cpp
#include "llvm/ADT/Statistic.h"
STATISTIC(NumFolded, "Number of instructions folded");

// 在 run() 方法中
++NumFolded;
```

### 4. Opt-Bisect（二分定位）

```bash
# 只运行前 N 个 Pass
opt -passes="default<O2>" -opt-bisect-limit=10 input.ll -S

# 输出示例：
# BISECT: running pass (1) Annotation2MetadataPass on [module]
# BISECT: running pass (2) ForceFunctionAttrsPass on [module]
# BISECT: NOT running pass (11) EarlyCSEPass on caller
```

**用途**：定位引入 bug 的具体 Pass，通过二分法快速缩小范围。

### 5. IR 验证

```bash
# 每个 Pass 后验证 IR 合法性
opt -passes="default<O2>" -verify-each input.ll -S -o /dev/null
```

如果某个 Pass 产生了非法 IR，验证器会立即报错并指出位置。

## IR 缩减工具

### llvm-extract（提取子集）

```bash
# 提取单个函数
llvm-extract -func=compute input.ll -S -o extracted.ll

# 提取单个基本块
llvm-extract -bb=funcName:bbName input.ll -S

# 提取多个函数
llvm-extract -func=foo -func=bar input.ll -S
```

**特点**：自动处理依赖（类型、全局变量、被调用函数），生成独立模块。

### llvm-reduce（自动缩减）

```bash
# 创建测试脚本（判断 IR 是否"有趣"）
cat > test.sh << 'EOF'
#!/bin/bash
grep -q "target_pattern" "$1"
EOF
chmod +x test.sh

# 运行缩减
llvm-reduce --test=./test.sh input.ll -o reduced.ll
```

**缩减策略**：
1. 删除函数
2. 简化函数体
3. 删除基本块
4. 简化指令
5. 删除参数/属性/元数据

**实践结果**：3 个函数 → `declare i32 @func2()`（仅保留声明）

### bugpoint（传统工具）

```bash
# 使用自定义测试脚本
bugpoint --compile-command=./test.sh --run-llc input.ll

# 注意：LLVM 19 仍可用，但推荐使用 llvm-reduce
```

## Sanitizers（运行时检测）

| Sanitizer | 检测目标 | 编译选项 |
|-----------|----------|----------|
| Address | 内存越界、use-after-free | `-fsanitize=address` |
| Memory | 未初始化内存读取 | `-fsanitize=memory` |
| Thread | 数据竞争 | `-fsanitize=thread` |
| Undefined | 未定义行为 | `-fsanitize=undefined` |
| DataFlow | 数据流敏感分析 | `-fsanitize=dataflow` |
| Leak | 内存泄漏 | `-fsanitize=leak` |

**启用方式**：
```bash
# 编译用户程序
clang -fsanitize=address -g program.c -o program

# 编译 LLVM 本身
cmake -DLLVM_USE_SANITIZER="Address" ...
```

**注意**：Sanitizers 会显著降低性能（2-10x），不适合常驻开启。

## LLDB 调试器

### 基本会话

```bash
# 启动调试
lldb -- opt -passes="instcombine" input.ll -S

# 常用命令
(lldb) r                    # 运行程序
(lldb) bt                   # 打印调用栈
(lldb) b filename:line      # 设置断点
(lldb) b functionName       # 在函数入口断点
(lldb) n                    # 单步（不进入函数）
(lldb) s                    # 单步（进入函数）
(lldb) finish               # 执行到当前函数返回
(lldb) p variable           # 打印变量
(lldb) x &variable          # 检查内存
```

### LLVM dump() 方法

```bash
# 在 LLDB 中使用 LLVM 的 dump() 方法
(lldb) p Instr.dump()
  %i = shl i32 5, 3

(lldb) p Instr.getType()->dump()
i32

(lldb) p Instr.getFunction()->dump()
define i32 @compute(...) { ... }
```

**注意**：`dump()` 方法仅在 assertions-enabled 构建中可用。若不可用，使用 `print()` 方法替代。

### 条件断点

```bash
(lldb) b BinaryOperator::BinaryOperator
(lldb) break modify 8 -c "Instr.getOpcode() == llvm::Instruction::Shl"
```

### Watchpoints（监视点）

```bash
# 监视变量写入
(lldb) watchpoint set variable -w write MyVar

# 监视内存地址
(lldb) watchpoint set expression -- 0x7fff5fbff8c0
```

## 实践观察

### 实验 1：print-after-all 跟踪 Pass 效果

```
; *** IR Dump After InstCombinePass on compute ***
define i32 @compute(i32 %a, i32 %b) {
entry:
  %sum = add i32 %a, %b
  %prod = mul i32 %sum, %a
  ...
```

每个函数分别运行 Pass，可以清楚看到优化效果。

### 实验 2：opt-bisect-limit 定位问题

```
BISECT: running pass (1) Annotation2MetadataPass on [module]
BISECT: running pass (2) ForceFunctionAttrsPass on [module]
BISECT: running pass (3) InferFunctionAttrsPass on [module]
BISECT: running pass (4) LowerExpectIntrinsicPass on compute
BISECT: running pass (5) SimplifyCFGPass on compute
BISECT: NOT running pass (11) EarlyCSEPass on caller
```

通过调整 limit 值，可以快速定位引入问题的 Pass。

### 实验 3：llvm-reduce 自动缩减

```
缩减前: 3 个函数，18 行
缩减后: declare i32 @func2()  (1 行)
```

llvm-reduce 通过多轮迭代，将测试用例缩减到最小，同时保持"有趣"属性。

### 实验 4：llvm-extract 提取基本块

```
输入: define i32 @compute(i32 %a, i32 %b) { ... then: ... }
输出: define void @compute.then(i32 %prod, i32 %b, ptr %res1.out) {
        newFuncRoot:
          br label %then
        then:
          %res1 = add i32 %prod, %b
          store i32 %res1, ptr %res1.out
          ...
      }
```

自动将基本块提升为独立函数，未定义的值变为参数，已定义但未消费的值变为输出参数。

## 关键收获

1. **调试流程**：print-after-all → 定位问题 Pass → 提取输入 → 单独运行 → 修复
2. **opt-bisect-limit 是二分神器**：快速定位引入 bug 的 Pass
3. **llvm-reduce 比 bugpoint 更现代**：推荐优先使用
4. **verify-each 保证正确性**：每个 Pass 后验证 IR 合法性
5. **dump() 方法是调试利器**：在 LLDB 中直接查看 LLVM 对象
6. **debug-only 需要 assertions-enabled**：系统 LLVM 通常不支持
7. **Sanitizers 适合深度排查**：内存问题、未定义行为等

## 调试工具速查表

```
┌──────────────────┬──────────────────────────────────────────────┐
│ 场景             │ 推荐工具                                     │
├──────────────────┼──────────────────────────────────────────────┤
│ 观察优化效果     │ -print-after-all / -print-before=<pass>      │
│ 定位问题 Pass    │ -opt-bisect-limit=N                          │
│ 查看 Pass 内部   │ -debug-only=<pass>（需 assertions）          │
│ 验证 IR 合法性   │ -verify-each                                 │
│ 提取函数/基本块  │ llvm-extract                                 │
│ 缩减测试用例     │ llvm-reduce                                  │
│ 内存/UB 问题     │ -fsanitize=address/undefined                 │
│ 交互式调试       │ LLDB + dump() 方法                           │
└──────────────────┴──────────────────────────────────────────────┘
```

## 待探索

- [ ] 在 assertions-enabled 的 LLVM 构建中体验 debug-only
- [ ] 使用 LLDB 调试自定义 Pass
- [ ] 使用 bugpoint 进行更复杂的缩减
