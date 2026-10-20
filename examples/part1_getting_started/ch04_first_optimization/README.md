# Chapter 4: Writing Your First Optimization Pass

## 学习目标

完成本章后，你将能够：
- ✅ 理解 LLVM Pass 的基本概念和分类
- ✅ 编写一个简单的优化 Pass（常量折叠）
- ✅ 使用 Legacy Pass Manager 注册和运行 Pass
- ✅ 观察 Pass 对 LLVM IR 的实际影响

---

## 4.1 什么是 Pass？

### 概念
**Pass** 是 LLVM 中执行特定编译任务的单元。整个编译过程就是由一系列 Pass 组成的流水线。

### Pass 的分类

| 类型 | 作用对象 | 示例 |
|------|---------|------|
| **Module Pass** | 整个 Module | 链接时优化、全局变量分析 |
| **Function Pass** | 单个 Function | 常量传播、死代码消除 |
| **BasicBlock Pass** | 单个 BasicBlock | 局部优化 |
| **Machine Function Pass** | MachineFunction | 后端优化 |

> **我们将从 Function Pass 开始**，因为它最常用，也最容易理解。

---

## 4.2 第一个 Pass：常量折叠

### 目标
编写一个 Pass，将常量表达式在编译期求值：

```llvm
; 优化前
%a = add i32 2, 3
%b = mul i32 %a, 4

; 优化后
%a = add i32 2, 3    ; → 5（但 LLVM 会保留）
%b = mul i32 5, 4    ; → 20
```

> **注意**: 实际的常量折叠由 LLVM 内置 Pass 完成，这里我们手写一个简化版本来学习 Pass 的结构。

---

## 4.3 Pass 代码结构

### 4.3.1 头文件

```cpp
#include "llvm/IR/PassManager.h"         // Pass 基础设施
#include "llvm/IR/Function.h"            // Function 类
#include "llvm/IR/Instructions.h"        // 指令类
#include "llvm/IR/Constants.h"           // 常量类
#include "llvm/Pass.h"                   // Pass 基类
#include "llvm/Support/raw_ostream.h"    // 输出流
```

### 4.3.2 定义 Pass 类

```cpp
namespace {
struct ConstFoldPass : public llvm::FunctionPass {
    static char ID;
    ConstFoldPass() : FunctionPass(ID) {}

    // 核心：runOnFunction 方法
    bool runOnFunction(llvm::Function &F) override {
        bool Changed = false;
        
        // 遍历所有基本块
        for (llvm::BasicBlock &BB : F) {
            // 遍历所有指令
            for (llvm::Instruction &I : BB) {
                // 尝试折叠二元运算符
                if (auto *BO = llvm::dyn_cast<llvm::BinaryOperator>(&I)) {
                    if (tryFoldBinaryOp(BO)) {
                        Changed = true;
                    }
                }
            }
        }
        
        return Changed;  // 返回是否修改了 IR
    }

private:
    bool tryFoldBinaryOp(llvm::BinaryOperator *BO) {
        // 检查两个操作数是否都是常量
        llvm::ConstantInt *LHS = llvm::dyn_cast<llvm::ConstantInt>(BO->getOperand(0));
        llvm::ConstantInt *RHS = llvm::dyn_cast<llvm::ConstantInt>(BO->getOperand(1));
        
        if (!LHS || !RHS) return false;
        
        // 根据操作码计算结果
        llvm::APInt Result(32, 0);
        llvm::APInt L = LHS->getValue();
        llvm::APInt R = RHS->getValue();
        
        switch (BO->getOpcode()) {
            case llvm::Instruction::Add:
                Result = L + R;
                break;
            case llvm::Instruction::Mul:
                Result = L * R;
                break;
            case llvm::Instruction::Sub:
                Result = L - R;
                break;
            default:
                return false;
        }
        
        // 用常量替换所有使用
        llvm::ConstantInt *NewConst = llvm::ConstantInt::get(BO->getType()->getContext(), Result);
        BO->replaceAllUsesWith(NewConst);
        BO->eraseFromParent();
        
        return true;
    }
};
}

char ConstFoldPass::ID = 0;
```

### 4.3.3 注册 Pass

```cpp
// 注册到 opt 工具
static llvm::RegisterPass<ConstFoldPass> X(
    "const-fold",           // 命令行参数名: opt -const-fold
    "Simple Constant Folding Pass",  // 描述
    false,                  // 是否只查看 CFG（不分析内容）
    false                   // 是否是分析 Pass
);
```

---

## 4.4 编译和运行

### 4.4.1 准备测试 IR

创建 `test_input.ll`：

```llvm
define i32 @test() {
entry:
  %a = add i32 2, 3
  %b = mul i32 %a, 4
  %c = add i32 %b, 10
  ret i32 %c
}
```

### 4.4.2 编译 Pass

```bash
# 假设 Pass 代码在 const_fold.cpp
clang++ -shared -fPIC -o ConstFoldPass.so const_fold.cpp \
    $(llvm-config --cxxflags) \
    -I/path/to/llvm/include \
    -L/path/to/llvm/lib \
    -lLLVM
```

### 4.4.3 运行 Pass

```bash
# 使用 opt 工具加载并运行 Pass
opt -load ./ConstFoldPass.so -const-fold < test_input.ll -S

# 预期输出
define i32 @test() {
entry:
  ret i32 30    ; 2+3=5, 5*4=20, 20+10=30
}
```

---

## 4.5 使用 New Pass Manager

> **注意**: LLVM 正在从 Legacy Pass Manager 迁移到 New Pass Manager。现代 LLVM 代码推荐使用 New Pass Manager。

### 4.5.1 New Pass Manager 版本

```cpp
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

namespace {
struct ConstFoldPassNew : public llvm::PassInfoMixin<ConstFoldPassNew> {
    llvm::PreservedAnalyses run(llvm::Function &F, llvm::FunctionAnalysisManager &) {
        bool Changed = false;
        
        // 同样的优化逻辑...
        
        return Changed ? llvm::PreservedAnalyses::none() 
                       : llvm::PreservedAnalyses::all();
    }
};
}

// 注册插件
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {LLVM_PLUGIN_API_VERSION, "ConstFoldPass", "1.0",
            [](llvm::PassBuilder &PB) {
                PB.registerPipelineParsingCallback(
                    [](llvm::StringRef Name, llvm::FunctionPassManager &FPM,
                       llvm::ArrayRef<llvm::PassBuilder::PipelineElement>) {
                        if (Name == "const-fold") {
                            FPM.addPass(ConstFoldPassNew());
                            return true;
                        }
                        return false;
                    });
            }};
}
```

### 4.5.2 运行 New Pass

```bash
opt -load-pass-plugin ./ConstFoldPassNew.so -passes="const-fold" < test_input.ll -S
```

---

## 4.6 实践练习

### 练习 1：扩展常量折叠
修改 Pass，支持更多操作：
- `shl`（左移）
- `lshr`（逻辑右移）
- `and`、`or`、`xor`

### 练习 2：添加日志输出
在 Pass 中添加调试信息：

```cpp
llvm::errs() << "Folding: " << *BO << "\n";
llvm::errs() << "  Result: " << *NewConst << "\n";
```

### 练习 3：处理更多类型
当前只支持 `i32`，扩展到支持 `i64`、`i8` 等整数类型。

---

## 4.7 调试技巧

### 4.7.1 打印 IR

```bash
# 每个 Pass 后打印 IR
opt -load ./ConstFoldPass.so -const-fold -print-after-all < test.ll -S
```

### 4.7.2 使用 LLVM_DEBUG

```cpp
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "const-fold"

// 在代码中使用
LLVM_DEBUG(llvm::errs() << "Processing: " << *BO << "\n");
```

运行：
```bash
opt -debug-only=const-fold -load ./ConstFoldPass.so -const-fold < test.ll -S
```

---

## 4.8 本章核心收获

1. **Pass 是 LLVM 编译流水线的构建块**
2. **Function Pass 是最常用的 Pass 类型**
3. **Pass 通过 `runOnFunction` 或 `run` 方法处理 IR**
4. **返回 `true`/`Changed` 表示 IR 被修改**
5. **Legacy 和 New Pass Manager 并存，新项目推荐 New**
6. **`opt` 工具是测试和调试 Pass 的利器**

---

## 4.9 参考资源

- LLVM Pass 文档: https://llvm.org/docs/WritingAnLLVMPass.html
- New Pass Manager: https://llvm.org/docs/NewPassManager.html
- `opt` 工具: https://llvm.org/docs/CommandGuide/opt.html
- 下一章: Chapter 5 - Pass Managers
