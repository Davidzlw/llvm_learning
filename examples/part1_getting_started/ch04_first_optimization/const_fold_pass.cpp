// 第4章实践：编写第一个优化 Pass
// 编译: clang++ -shared -fPIC -o ConstFoldPass.so const_fold_pass.cpp $(llvm-config --cxxflags --ldflags --libs core support)
// 运行: opt -load ./ConstFoldPass.so -const-fold < test_input.ll -S

#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Constants.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

using namespace llvm;

namespace {
struct ConstFoldPass : public FunctionPass {
    static char ID;
    ConstFoldPass() : FunctionPass(ID) {}

    bool runOnFunction(Function &F) override {
        bool Changed = false;
        
        errs() << "Running ConstFoldPass on function: " << F.getName() << "\n";
        
        // 遍历所有基本块
        for (BasicBlock &BB : F) {
            // 注意：遍历时需要小心，因为我们会删除指令
            for (auto It = BB.begin(); It != BB.end(); ) {
                Instruction &I = *It++;
                
                // 只处理二元运算符
                if (auto *BO = dyn_cast<BinaryOperator>(&I)) {
                    if (tryFoldBinaryOp(BO)) {
                        Changed = true;
                    }
                }
            }
        }
        
        return Changed;
    }

private:
    bool tryFoldBinaryOp(BinaryOperator *BO) {
        // 检查两个操作数是否都是常量整数
        ConstantInt *LHS = dyn_cast<ConstantInt>(BO->getOperand(0));
        ConstantInt *RHS = dyn_cast<ConstantInt>(BO->getOperand(1));
        
        if (!LHS || !RHS) return false;
        
        // 获取操作码和操作数
        APInt Result(32, 0);
        APInt L = LHS->getValue();
        APInt R = RHS->getValue();
        
        // 根据操作码计算
        switch (BO->getOpcode()) {
            case Instruction::Add:
                Result = L + R;
                errs() << "  Folding add: " << L << " + " << R << " = " << Result << "\n";
                break;
            case Instruction::Mul:
                Result = L * R;
                errs() << "  Folding mul: " << L << " * " << R << " = " << Result << "\n";
                break;
            case Instruction::Sub:
                Result = L - R;
                errs() << "  Folding sub: " << L << " - " << R << " = " << Result << "\n";
                break;
            default:
                return false;
        }
        
        // 创建新的常量并替换
        ConstantInt *NewConst = ConstantInt::get(BO->getType()->getContext(), Result);
        BO->replaceAllUsesWith(NewConst);
        BO->eraseFromParent();
        
        return true;
    }
};
}

char ConstFoldPass::ID = 0;

// 注册 Pass
static RegisterPass<ConstFoldPass> X(
    "const-fold",                    // 命令行参数: opt -const-fold
    "Simple Constant Folding Pass",  // 描述
    false,                           // 是否只查看 CFG
    false                            // 是否是分析 Pass
);
