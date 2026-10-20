; 测试栈帧 - 局部变量和 spill
define i32 @stack_test(i32 %a, i32 %b) {
  %local1 = alloca i32
  %local2 = alloca i32
  store i32 %a, i32* %local1
  store i32 %b, i32* %local2
  %v1 = load i32, i32* %local1
  %v2 = load i32, i32* %local2
  %sum = add i32 %v1, %v2
  ret i32 %sum
}

; 测试函数调用 - 参数传递
declare i32 @external(i32, i32)

define i32 @caller(i32 %x) {
  %ret = call i32 @external(i32 %x, i32 42)
  ret i32 %ret
}

; 测试大栈帧 - 数组
define i32 @large_stack() {
  %arr = alloca [100 x i32]
  %ptr = getelementptr [100 x i32], [100 x i32]* %arr, i32 0, i32 0
  store i32 999, i32* %ptr
  %val = load i32, i32* %ptr
  ret i32 %val
}
