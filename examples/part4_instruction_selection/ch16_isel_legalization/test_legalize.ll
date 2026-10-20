; 测试类型合法化
define i8 @add_i8(i8 %a, i8 %b) {
  %sum = add i8 %a, %b
  ret i8 %sum
}

define i16 @add_i16(i16 %a, i16 %b) {
  %sum = add i16 %a, %b
  ret i16 %sum
}

define i64 @add_i64(i64 %a, i64 %b) {
  %sum = add i64 %a, %b
  ret i64 %sum
}

; 测试向量类型合法化
define <3 x i8> @add_vec3(<3 x i8> %a, <3 x i8> %b) {
  %sum = add <3 x i8> %a, %b
  ret <3 x i8> %sum
}

define <4 x i16> @add_vec4(<4 x i16> %a, <4 x i16> %b) {
  %sum = add <4 x i16> %a, %b
  ret <4 x i16> %sum
}

; 测试浮点操作合法化
define float @add_float(float %a, float %b) {
  %sum = fadd float %a, %b
  ret float %sum
}

define double @add_double(double %a, double %b) {
  %sum = fadd double %a, %b
  ret double %sum
}

; 测试乘法合法化（可能需要库调用）
define i32 @mul_i32(i32 %a, i32 %b) {
  %prod = mul i32 %a, %b
  ret i32 %prod
}
