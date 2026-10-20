// Chapter 6 实践：multiclass 和 defm
// 运行: llvm-tblgen multiclass_example.td

// multiclass: 一次生成多个 record
multiclass Bundle<string base> {
  def A {
    string name = !strconcat(base, "-", "A");
    int price = 12;
    int weight = 1;
  }
  def B {
    string name = !strconcat(base, "-", "B");
    int price = 8;
    int weight = 2;
  }
  def C {
    string name = !strconcat(base, "-", "C");
    int price = 15;
    int weight = 3;
  }
}

// 使用 defm 实例化 multiclass
// 会生成: valuedBundleA, valuedBundleB, valuedBundleC
defm valuedBundle : Bundle<"valued">;

// 另一个实例
// 会生成: premiumBundleA, premiumBundleB, premiumBundleC
defm premiumBundle : Bundle<"premium">;

// 展示 let 语句的作用域覆盖
class Config {
  string mode = "default";
  int level = 0;
}

let mode = "production" in {
  def ProdConfig : Config {
    let level = 3;
  }
  def ProdConfig2 : Config;  // mode 也被覆盖为 "production"
}

def DevConfig : Config {
  let mode = "development";
  let level = 1;
}
