declare i32 @external_func(i32 %a, i32 %b, i32 %c)

define i32 @caller(i32 %x, i32 %y) {
  %sum = add i32 %x, %y
  %ret = call i32 @external_func(i32 %sum, i32 %x, i32 %y)
  ret i32 %ret
}

define i32 @callee(i32 %a, i32 %b, i32 %c, i32 %d) {
  %sum1 = add i32 %a, %b
  %sum2 = add i32 %c, %d
  %total = add i32 %sum1, %sum2
  ret i32 %total
}
