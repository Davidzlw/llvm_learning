define i32 @add(i32 %a, i32 %b) {
  %sum = add i32 %a, %b
  ret i32 %sum
}

define i32 @compute() {
  %r = call i32 @add(i32 10, i32 20)
  ret i32 %r
}
