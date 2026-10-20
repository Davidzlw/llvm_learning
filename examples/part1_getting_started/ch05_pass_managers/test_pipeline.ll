; Chapter 5 实践：观察 Pass 流水线
; 这个测试文件包含 alloca/load/store（mem2reg 可优化）
; 以及常量表达式（instcombine 可优化）
; 以及可内联的函数调用（alwaysinline 可优化）

; 带有 alwaysinline 属性的函数
define void @helper(i32* %p) alwaysinline {
entry:
  store i32 42, i32* %p
  ret void
}

; 主函数：包含 alloca、常量运算、函数调用
define i32 @main_test() {
entry:
  ; 使用 alloca + load/store（mem2reg 可以提升为 SSA）
  %x = alloca i32
  %y = alloca i32
  store i32 10, i32* %x
  store i32 20, i32* %y
  
  ; 调用 helper 函数
  call void @helper(i32* %x)
  
  ; 加载并计算
  %a = load i32, i32* %x
  %b = load i32, i32* %y
  %c = add i32 %a, %b
  %d = mul i32 %c, 2
  
  ; 常量表达式（instcombine 可以折叠）
  %e = add i32 100, 200
  %f = add i32 %d, %e
  
  ret i32 %f
}

; 另一个测试函数：纯常量计算
define i32 @pure_const() {
entry:
  %a = add i32 5, 3
  %b = mul i32 %a, 4
  %c = sub i32 %b, 10
  ret i32 %c
}
