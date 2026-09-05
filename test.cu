// 简单的CUDA测试程序
#include <stdio.h>

__global__ void helloKernel() {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    printf("Hello from GPU thread %d\n", tid);
}

int main() {
    helloKernel<<<1, 32>>>();
    cudaDeviceSynchronize();
    return 0;
}
