// Chapter 6 实践：TableGen 基础
// 运行: llvm-tblgen person.td

// 定义一个 class
class Person {
  string name = "";
  int age = 0;
}

// 使用 class 参数化
class Employee<string _name, int _age, string _dept> : Person {
  let name = _name;
  let age = _age;
  string department = _dept;
}

// 实例化 records
def Alice : Employee<"Alice", 30, "Engineering">;
def Bob : Employee<"Bob", 25, "Marketing">;

// 匿名 record
def : Person {
  let name = "Charlie";
  let age = 35;
}
