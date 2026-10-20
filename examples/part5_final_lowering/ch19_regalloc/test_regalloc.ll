; 测试寄存器压力 - 多个活跃变量
define i32 @high_pressure(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e) {
  %t1 = add i32 %a, %b
  %t2 = add i32 %c, %d
  %t3 = mul i32 %t1, %t2
  %t4 = add i32 %t3, %e
  %t5 = sub i32 %t4, %a
  %t6 = mul i32 %t5, %b
  %t7 = add i32 %t6, %c
  ret i32 %t7
}

; 测试长生命周期变量
define i32 @long_live(i32 %x) {
  %a = add i32 %x, 1
  %b = add i32 %a, 2
  %c = add i32 %b, 3
  %d = add i32 %c, 4
  %e = add i32 %d, 5
  %f = add i32 %e, 6
  %g = add i32 %f, 7
  %h = add i32 %g, 8
  %i = add i32 %h, 9
  %j = add i32 %i, 10
  ret i32 %j
}

; 测试分支合并 (phi 节点)
define i32 @phi_merge(i32 %a, i32 %b, i1 %cond) {
  br i1 %cond, label %then, label %else

then:
  %t1 = add i32 %a, 10
  br label %merge

else:
  %t2 = add i32 %b, 20
  br label %merge

merge:
  %result = phi i32 [%t1, %then], [%t2, %else]
  ret i32 %result
}
