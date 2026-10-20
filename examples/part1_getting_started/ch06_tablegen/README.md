# Chapter 6: TableGen – LLVM Swiss Army Knife for Modeling

## 学习目标

完成本章后，你将能够：
- ✅ 理解 TableGen 的概念和用途
- ✅ 掌握 TableGen 的基本语法（class, def, multiclass, defm, let）
- ✅ 使用 `llvm-tblgen` 工具处理 `.td` 文件
- ✅ 理解 TableGen 在 LLVM 后端中的实际作用

---

## 6.1 什么是 TableGen？

### 概念

**TableGen** 是 LLVM 的领域特定语言（DSL），用于声明式地描述目标机器的各种属性，然后由 `llvm-tblgen` 工具将其转换为 C++ 代码（`.inc` 文件）。

> 名字来源于其最初用途——生成表格（如寄存器表）。现已扩展到描述指令、特性、 intrinsic 等几乎所有后端信息。

### 工作流程

```
输入 (.td 文件)
    ↓
llvm-tblgen 前端（展开 records）
    ↓
llvm-tblgen 后端（--gen-xxx）
    ↓
输出 (.inc C++ 文件)
    ↓
#include 到 LLVM 源码中
```

### 为什么使用 TableGen？

| 方式 | 纯 C++ | TableGen |
|------|--------|---------|
| 描述方式 | 命令式 | 声明式 |
| 维护成本 | 高（重复代码多） | 低（模板复用） |
| 可读性 | 分散在各处 | 集中在 `.td` 文件 |
| 扩展性 | 需改 C++ 代码 | 只需添加 records |

---

## 6.2 TableGen 语法

### 6.2.1 基本构建块

#### class — 定义模板

```tablegen
class Person {
  string name = "";
  int age = 0;
}
```

#### def — 实例化 record

```tablegen
def Alice : Person {
  let name = "Alice";
  let age = 30;
}
```

#### 带参数的 class

```tablegen
class Employee<string _name, int _age, string _dept> : Person {
  let name = _name;
  let age = _age;
  string department = _dept;
}

def Bob : Employee<"Bob", 25, "Marketing">;
```

### 6.2.2 内置类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `int` | 64 位整数 | `42`, `0xFF`, `0b1010` |
| `bit` | 0 或 1 | `0`, `1` |
| `bits<N>` | N 位二进制 | `0b1010` |
| `string` | 字符串 | `"hello"` |
| `list<T>` | 列表 | `[1, 2, 3]` |
| `dag` | 有向无环图 | `(add a, b)` |

### 6.2.3 multiclass 和 defm

`multiclass` 一次定义多个 records，`defm` 一次实例化全部：

```tablegen
multiclass Bundle<string base> {
  def A {
    string name = !strconcat(base, "-", "A");
    int price = 12;
  }
  def B {
    string name = !strconcat(base, "-", "B");
    int price = 8;
  }
}

// 生成: valuedBundleA, valuedBundleB
defm valuedBundle : Bundle<"valued">;
```

### 6.2.4 let 语句与字段覆盖

`let` 可以覆盖字段值，支持作用域：

```tablegen
class Config {
  string mode = "default";
  int level = 0;
}

// 作用域覆盖：块内所有 records 的 mode 都被设为 "production"
let mode = "production" in {
  def ProdA : Config;     // mode = "production", level = 0
  def ProdB : Config {
    let level = 3;         // mode = "production", level = 3
  }
}
```

**覆盖优先级**（从低到高）：
1. class 默认值
2. class 参数传入
3. record 体内 `let`
4. record 体外 `let ... in` 作用域

### 6.2.5 字符串操作

```tablegen
// 拼接
string name = !strconcat(base, "-", "A");

// 连接操作符 #
"sm_" # sm    // 如 sm = "89" → "sm_89"
```

---

## 6.3 TableGen 后端

### 6.3.1 工作原理

所有 LLVM TableGen 后端遵循相同模式：

1. **输入**: `.td` 文件中的 records
2. **处理**: 后端 C++ 代码遍历 records，提取信息
3. **输出**: `.inc` 文件（C++ 代码片段）
4. **使用**: 通过 `#ifdef` 宏分段 include 到 LLVM 源码

### 6.3.2 常用后端

| 后端选项 | 功能 | 输出示例 |
|---------|------|---------|
| `--gen-instr-info` | 指令信息 | `XXXGenInstrInfo.inc` |
| `--gen-register-info` | 寄存器信息 | `XXXGenRegisterInfo.inc` |
| `--gen-subtarget` | 子目标特性 | `XXXGenSubtargetInfo.inc` |
| `--gen-intrinsic-impl` | Intrinsic 实现 | `IntrinsicImpl.inc` |
| `--gen-dag-isel` | DAG 指令选择器 | `XXXGenDAGISel.inc` |
| `--gen-asm-writer` | 汇编写入器 | `XXXGenAsmWriter.inc` |
| `--gen-disassembler` | 反汇编器 | `XXXGenDisassemblerTables.inc` |

### 6.3.3 实际案例：NVPTX 后端

NVPTX 后端使用 TableGen 描述 GPU 特性：

```tablegen
// NVPTX.td 片段
include "llvm/Target/Target.td"
include "NVPTXRegisterInfo.td"
include "NVPTXInstrInfo.td"

// 定义 SM 特性
class FeatureSM<string sm, int value>:
   SubtargetFeature<"sm_"# sm, "FullSmVersion",
                    "" # value, "Target SM " # sm>;

// 批量生成 SM20~SM90
foreach sm = [20, 21, 30, ..., 89, 90] in
  def SM#sm: FeatureSM<""#sm, !mul(sm, 10)>;

// 定义支持的 GPU
def : Proc<"sm_89", [SM89]>;  // RTX 4090
```

---

## 6.4 实践

### 6.4.1 运行 TableGen

```bash
# 打印展开后的 records
llvm-tblgen person.td

# 使用后端生成代码（需要完整的 .td 文件）
llvm-tblgen --gen-instr-info -I include/ NVPTX.td
```

### 6.4.2 观察结果

运行 `llvm-tblgen person.td` 输出：

```
------------- Classes -----------------
class Employee<string _name, int _age, string _dept> { // Person
  string name = Employee:_name;
  int age = Employee:_age;
  string department = Employee:_dept;
}
class Person {
  string name = "";
  int age = 0;
}
------------- Defs -----------------
def Alice { // Person Employee
  string name = "Alice";
  int age = 30;
  string department = "Engineering";
}
```

**关键观察**：
- `class` 不会出现在 Defs 中（它们是模板，不是实例）
- `def` 展开后显示所有继承的字段
- 匿名 record 被自动命名为 `anonymous_0`

### 6.4.3 multiclass 展开

运行 `llvm-tblgen multiclass_example.td`：

```
def valuedBundleA { string name = "valued-A"; int price = 12; ... }
def valuedBundleB { string name = "valued-B"; int price = 8;  ... }
def valuedBundleC { string name = "valued-C"; int price = 15; ... }
def premiumBundleA { string name = "premium-A"; ... }
```

**关键观察**：
- `defm valuedBundle : Bundle<"valued">` 展开为 3 个独立 records
- 名称自动拼接：`defm` 名 + multiclass 内 `def` 名

---

## 6.5 调试 TableGen

### 识别错误来源

| 失败时机 | 可能原因 |
|---------|---------|
| 生成 `.inc` 时 | 前端语法错误 或 后端特定构造使用错误 |
| 编译 `.inc` 时 | 后端生成代码问题 或 record 描述不正确 |
| 运行时 | 后端逻辑问题 或 record 描述不正确 |

### 排查步骤

```bash
# 1. 检查前端是否能正常解析
llvm-tblgen input.td  # 不带 --gen-xxx

# 2. 如果前端正常，问题在后端
llvm-tblgen --gen-xxx input.td

# 3. 启用调试日志
llvm-tblgen --gen-xxx -debug input.td
```

---

## 6.6 核心收获

1. **TableGen 是 LLVM 的声明式建模语言**，将目标机器信息从 C++ 代码中解耦
2. **核心概念**：`class`（模板）、`def`（实例化）、`multiclass/defm`（批量生成）、`let`（字段覆盖）
3. **工作流程**：`.td` → `llvm-tblgen` → `.inc` → `#include` 到 LLVM 源码
4. **所有 LLVM 后端都依赖 TableGen** 描述寄存器、指令、特性、intrinsic 等
5. **没有头文件保护机制**——include 是传递性的，重复 include 会导致重定义错误
6. **record 名称有语义**——某些后端依赖特定名称的 records（如 `IntrArgMemOnly`）
7. **调试技巧**：先用 `llvm-tblgen file.td`（不带后端）验证前端，再启用具体后端

---

## 6.7 参考资源

- TableGen 官方文档: https://llvm.org/docs/TableGen/
- TableGen 编程参考: https://llvm.org/docs/TableGen/ProgRef.html
- NVPTX 后端: `llvm/lib/Target/NVPTX/`
- 下一章: Chapter 7 - Understanding LLVM IR
