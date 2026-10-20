define i32 @simple_add(i32 %a, i32 %b) {
  %sum = add i32 %a, %b
  ret i32 %sum
}

define i32 @with_call(i32 %x) {
  %ret = call i32 @external_func(i32 %x)
  ret i32 %ret
}

declare i32 @external_func(i32)
