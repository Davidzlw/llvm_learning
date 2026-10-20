; 测试指令调度 - 依赖链
define i32 @chain(i32 %a, i32 %b, i32 %c) {
  %add1 = add i32 %a, %b
  %add2 = add i32 %add1, %c
  %add3 = add i32 %add2, %a
  %add4 = add i32 %add3, %b
  ret i32 %add4
}

; 测试独立操作 - 可并行
define i32 @parallel(i32 %a, i32 %b, i32 %c, i32 %d) {
  %add1 = add i32 %a, %b
  %add2 = add i32 %c, %d
  %mul1 = mul i32 %add1, %add2
  %sub1 = sub i32 %a, %c
  %sub2 = sub i32 %b, %d
  %add3 = add i32 %sub1, %sub2
  %result = add i32 %mul1, %add3
  ret i32 %result
}

; 测试内存操作
define i32 @memory(i32* %ptr1, i32* %ptr2, i32 %val) {
  %v1 = load i32, i32* %ptr1
  %v2 = load i32, i32* %ptr2
  store i32 %val, i32* %ptr1
  %sum = add i32 %v1, %v2
  ret i32 %sum
}

; 测试浮点操作
define float @float_ops(float %a, float %b, float %c) {
  %mul = fmul float %a, %b
  %add = fadd float %mul, %c
  %div = fdiv float %add, %a
  ret float %div
}
