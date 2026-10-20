define i32 @func1(i32 %a) {
  %b = add i32 %a, 1
  %c = add i32 %b, 1
  %d = add i32 %c, 1
  %e = add i32 %d, 1
  ret i32 %e
}

define i32 @func2(i32 %x) {
  %y = mul i32 %x, 2
  %z = add i32 %y, 3
  ret i32 %z
}

define i32 @func3(i32 %p) {
  %q = sub i32 %p, 5
  ret i32 %q
}
