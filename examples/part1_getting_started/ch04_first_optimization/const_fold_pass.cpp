// 第4章实践：编写第一个优化 Pass (New Pass Manager 版本)
// 编译: clang++ -shared -fPIC -o ConstFoldPass.so const_fold_pass.cpp $(llvm-config --cxxflags --ldflags) -fno-rtti
// 运行: opt -load-pass-plugin ./ConstFoldPass.so -passes="const-fold" < test_input.ll -S

#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
struct ConstFoldPass : public PassInfoMixin<ConstFoldPass> {
    PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
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
        
        return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
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

// 注册插件 (New Pass Manager)
extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {LLVM_PLUGIN_API_VERSION, "ConstFoldPass", "1.0",
            [](PassBuilder &PB) {
                PB.registerPipelineParsingCallback(
                    [](StringRef Name, FunctionPassManager &FPM,
                       ArrayRef<PassBuilder::PipelineElement>) {
                        if (Name == "const-fold") {
                            FPM.addPass(ConstFoldPass());
                            return true;
                        }
                        return false;
                    });
            }};
}
