define i32 @compute(i32 %a, i32 %b) {
entry:
  %sum = add i32 %a, %b
  %prod = mul i32 %sum, %a
  %cmp = icmp sgt i32 %prod, 100
  br i1 %cmp, label %then, label %else

then:
  %res1 = add i32 %prod, %b
  ret i32 %res1

else:
  %res2 = sub i32 %prod, %b
  ret i32 %res2
}

define i32 @caller() {
  %r = call i32 @compute(i32 10, i32 20)
  ret i32 %r
}

define void @unused_func() {
  ret void
}
