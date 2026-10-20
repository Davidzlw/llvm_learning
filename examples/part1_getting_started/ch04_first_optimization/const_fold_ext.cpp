// Chapter 4 练习：扩展版常量折叠 Pass
// 支持: add, sub, mul, shl, lshr, and, or, xor
// 支持: 任意位宽整数类型 (i8, i16, i32, i64 等)
//
// 编译: clang++ -shared -fPIC -o ConstFoldExtPass.so const_fold_ext.cpp $(llvm-config --cxxflags --ldflags) -fno-rtti
// 运行: opt -load-pass-plugin ./ConstFoldExtPass.so -passes="const-fold-ext" < test_extended.ll -S

#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
struct ConstFoldExtPass : public PassInfoMixin<ConstFoldExtPass> {
    PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
        bool Changed = false;

        errs() << "[ConstFoldExt] Processing function: " << F.getName() << "\n";

        for (BasicBlock &BB : F) {
            for (auto It = BB.begin(); It != BB.end(); ) {
                Instruction &I = *It++;
                if (auto *BO = dyn_cast<BinaryOperator>(&I)) {
                    if (tryFold(BO)) {
                        Changed = true;
                    }
                }
            }
        }

        return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
    }

private:
    bool tryFold(BinaryOperator *BO) {
        ConstantInt *LHS = dyn_cast<ConstantInt>(BO->getOperand(0));
        ConstantInt *RHS = dyn_cast<ConstantInt>(BO->getOperand(1));

        if (!LHS || !RHS) return false;

        unsigned BitWidth = LHS->getBitWidth();
        APInt L = LHS->getValue();
        APInt R = RHS->getValue();
        APInt Result(BitWidth, 0);
        bool Folded = true;

        switch (BO->getOpcode()) {
            case Instruction::Add:   Result = L + R;  break;
            case Instruction::Sub:   Result = L - R;  break;
            case Instruction::Mul:   Result = L * R;  break;
            case Instruction::Shl:   Result = L.shl(R);  break;
            case Instruction::LShr:  Result = L.lshr(R); break;
            case Instruction::And:   Result = L & R;  break;
            case Instruction::Or:    Result = L | R;  break;
            case Instruction::Xor:   Result = L ^ R;  break;
            default:                 Folded = false;   break;
        }

        if (!Folded) return false;

        errs() << "  Folded: " << *LHS << " "
               << BO->getOpcodeName() << " "
               << *RHS << " = " << Result
               << " (i" << BitWidth << ")\n";

        ConstantInt *NewConst = ConstantInt::get(BO->getType()->getContext(), Result);
        BO->replaceAllUsesWith(NewConst);
        BO->eraseFromParent();
        return true;
    }
};
} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {LLVM_PLUGIN_API_VERSION, "ConstFoldExtPass", "1.0",
            [](PassBuilder &PB) {
                PB.registerPipelineParsingCallback(
                    [](StringRef Name, FunctionPassManager &FPM,
                       ArrayRef<PassBuilder::PipelineElement>) {
                        if (Name == "const-fold-ext") {
                            FPM.addPass(ConstFoldExtPass());
                            return true;
                        }
                        return false;
                    });
            }};
}
