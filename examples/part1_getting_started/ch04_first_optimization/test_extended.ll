; 扩展测试：更多操作和类型

define i32 @test_bitwise() {
entry:
  %a = shl i32 1, 3         ; 1 << 3 = 8
  %b = lshr i32 16, 2       ; 16 >> 2 = 4
  %c = and i32 %a, 12       ; 8 & 12 = 8
  %d = or i32 %c, %b        ; 8 | 4 = 12
  %e = xor i32 %d, 5        ; 12 ^ 5 = 9
  ret i32 %e
}

define i64 @test_i64() {
entry:
  %a = add i64 1000000000, 2000000000   ; 3000000000
  %b = mul i64 %a, 2                     ; 6000000000
  ret i64 %b
}

define i8 @test_i8() {
entry:
  %a = add i8 100, 50     ; 150
  %b = sub i8 %a, 30      ; 120
  ret i8 %b
}
