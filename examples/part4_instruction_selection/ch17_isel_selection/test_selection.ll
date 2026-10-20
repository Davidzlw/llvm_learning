; 简单算术操作 - 观察指令选择模式
define i32 @arithmetic(i32 %a, i32 %b, i32 %c) {
  %mul = mul i32 %a, %b
  %add = add i32 %mul, %c
  %sub = sub i32 %add, %a
  ret i32 %sub
}

; 地址模式 - 观察复杂模式匹配
define i32 @load_offset(i32* %ptr, i32 %offset) {
  %addr = getelementptr i32, i32* %ptr, i32 %offset
  %val = load i32, i32* %addr
  ret i32 %val
}

; 条件分支 - 观察选择模式
define i32 @select_max(i32 %a, i32 %b) {
  %cmp = icmp sgt i32 %a, %b
  %result = select i1 %cmp, i32 %a, i32 %b
  ret i32 %result
}

; 向量操作 - 观察 SIMD 选择
define <4 x i32> @vec_add(<4 x i32> %a, <4 x i32> %b) {
  %sum = add <4 x i32> %a, %b
  ret <4 x i32> %sum
}
