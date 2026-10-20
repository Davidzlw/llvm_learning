define i32 @compute(i32 %a, i32 %b, i32 %c) {
entry:
  %sum1 = add i32 %a, %b
  %sum2 = add i32 %sum1, %c
  %mul = mul i32 %sum2, 2
  %cmp = icmp sgt i32 %mul, 100
  br i1 %cmp, label %then, label %else

then:
  %res1 = add i32 %mul, %a
  ret i32 %res1

else:
  %res2 = sub i32 %mul, %b
  ret i32 %res2
}
