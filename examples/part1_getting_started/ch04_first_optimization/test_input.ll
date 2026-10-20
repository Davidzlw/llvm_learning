; 测试输入：包含可折叠的常量表达式
; 预期：2+3=5, 5*4=20, 20+10=30

define i32 @test_const_fold() {
entry:
  %a = add i32 2, 3        ; 2 + 3 = 5
  %b = mul i32 %a, 4       ; 5 * 4 = 20
  %c = add i32 %b, 10      ; 20 + 10 = 30
  ret i32 %c
}

; 这个函数包含变量，无法完全折叠
define i32 @test_partial(i32 %x) {
entry:
  %a = add i32 10, 20      ; 可以折叠: 30
  %b = add i32 %a, %x      ; 无法折叠（有变量）
  ret i32 %b
}
