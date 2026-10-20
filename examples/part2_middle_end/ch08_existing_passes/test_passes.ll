// Chapter 8 实践：观察各种 Pass 的效果
// 包含多种可被不同 Pass 优化的模式

// 1. 死代码 + 死参数 (deadargelim)
define internal i32 @dead_arg_func(i32 %used, i32 %unused) {
entry:
  ret i32 %used
}

define i32 @caller(i32 %a, i32 %b) {
entry:
  %r = call i32 @dead_arg_func(i32 %a, i32 %b)
  ret i32 %r
}

// 2. 公共子表达式 (earlycse / gvn)
define i32 @cse_test(i32 %a, i32 %b) {
entry:
  %x = add i32 %a, %b
  %y = add i32 %a, %b    ; 与 %x 相同
  %z = mul i32 %x, %y
  ret i32 %z
}

// 3. 标量替换聚合 (sroa)
define i32 @sroa_test() {
entry:
  %p = alloca i32
  %q = alloca i32
  store i32 10, ptr %p
  store i32 20, ptr %q
  %a = load i32, ptr %p
  %b = load i32, ptr %q
  %c = add i32 %a, %b
  ret i32 %c
}

// 4. 跳转线程 (jumpthreading)
define i32 @jump_thread(i32 %x) {
entry:
  %cond = icmp sgt i32 %x, 0
  br i1 %cond, label %then, label %else

then:
  %cmp2 = icmp sgt i32 %x, 0   ; 与 entry 中的条件相同
  br i1 %cmp2, label %a, label %b

else:
  br label %b

a:
  ret i32 1

b:
  ret i32 0
}

// 5. CFG 简化 (simplifycfg)
define i32 @cfg_simplify(i32 %x) {
entry:
  br label %next

next:
  br i1 false, label %a, label %b   ; 常量条件

a:
  ret i32 1

b:
  ret i32 %x
}

// 6. 循环不变量外提 (licm)
define void @licm_test(ptr %arr, i32 %n, i32 %factor) {
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %iv_next, %loop ]
  %iv_next = add i32 %iv, 1
  %addr = getelementptr i32, ptr %arr, i32 %iv
  %val = load i32, ptr %addr
  %scaled = mul i32 %factor, 10   ; 循环不变量!
  %result = add i32 %val, %scaled
  store i32 %result, ptr %addr
  %exit = icmp slt i32 %iv_next, %n
  br i1 %exit, label %loop, label %end

end:
  ret void
}

// 7. Reassociate
define i32 @reassoc(i32 %a, i32 %b) {
entry:
  %v0 = add i32 %a, %b
  %v1 = add i32 %v0, 2
  %v2 = sub i32 %v1, %b
  ret i32 %v2
}
