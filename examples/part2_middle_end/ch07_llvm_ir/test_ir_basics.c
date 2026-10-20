// Chapter 7 实践：C 代码 → LLVM IR 映射
// 用于观察类型、指令、函数、基本块的 IR 表示

#include <stddef.h>

// 1. 基本类型和算术
int basic_arithmetic(int a, int b) {
    int sum = a + b;
    int prod = sum * 2;
    int shifted = prod << 3;
    return shifted;
}

// 2. 控制流 (if-else → 基本块 + 分支)
int control_flow(int x) {
    if (x > 10) {
        return x * 2;
    } else {
        return x + 5;
    }
}

// 3. 循环 → 回边 (backedge)
int loop_sum(int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += i;
    }
    return sum;
}

// 4. 结构体 (aggregate type)
struct Point {
    int x;
    int y;
};

int struct_access(struct Point* p) {
    return p->x + p->y;
}

// 5. 数组 (array type)
int array_sum(int arr[4]) {
    int sum = 0;
    for (int i = 0; i < 4; i++) {
        sum += arr[i];
    }
    return sum;
}

// 6. 全局变量
int global_counter = 0;
void increment_counter() {
    global_counter++;
}
