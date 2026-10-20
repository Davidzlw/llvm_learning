define i32 @add(i32 %a, i32 %b) {
  %sum = add i32 %a, %b
  ret i32 %sum
}

define i32 @mul_add(i32 %a, i32 %b, i32 %c) {
  %mul = mul i32 %a, %b
  %sum = add i32 %mul, %c
  ret i32 %sum
}
