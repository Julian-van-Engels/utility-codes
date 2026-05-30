"""
单核 CPU 性能基准测试脚本（纯 Python 标准库）
用法: python3 cpu_benchmark.py
"""

import time
import math
import random
import hashlib
import json


# ============================================================
# 1. 整数运算（大量加减乘除）
# ============================================================
def benchmark_integer():
    a = 0
    for i in range(2000):
        for j in range(100000):
            a += i * j
    return a


# ============================================================
# 2. 浮点运算（三角函数 + 指数对数）
# ============================================================
def benchmark_float():
    result = 0.0
    for i in range(1, 1000000):
        result += math.sin(i) * math.cos(i) + math.log(i + 1) * math.exp(-i / 1000000)
    return result


# ============================================================
# 3. 质数筛（Eratosthenes 算法，测分支预测和内存访问）
# ============================================================
def benchmark_prime_sieve(limit=20000000):
    sieve = bytearray(b'\x01') * (limit + 1)
    sieve[0:2] = b'\x00\x00'
    for i in range(2, int(limit ** 0.5) + 1):
        if sieve[i]:
            step = i
            start = i * i
            sieve[start:limit + 1:step] = b'\x00' * ((limit - start) // step + 1)
    return sum(1 for v in sieve if v)


# ============================================================
# 4. 递归斐波那契（测函数调用开销）
# ============================================================
def _fib(n):
    if n <= 1:
        return n
    return _fib(n - 1) + _fib(n - 2)


def benchmark_fibonacci(n=38):
    return _fib(n)


# ============================================================
# 5. 矩阵乘法（测嵌套循环 + 数据局部性）
# ============================================================
def benchmark_matrix(size=200):
    a = [[(i + j) % 100 * 0.01 for j in range(size)] for i in range(size)]
    b = [[(i - j) % 100 * 0.01 for j in range(size)] for i in range(size)]
    c = [[0.0] * size for _ in range(size)]
    for i in range(size):
        ai = a[i]
        ci = c[i]
        for k in range(size):
            aik = ai[k]
            bk = b[k]
            for j in range(size):
                ci[j] += aik * bk[j]
    return sum(sum(row) for row in c)


# ============================================================
# 6. SHA-256 哈希（测加密计算能力）
# ============================================================
def benchmark_hash(iterations=200000):
    data = b"A quick brown fox jumps over the lazy dog. " * 10
    h = hashlib.sha256()
    for i in range(iterations):
        h.update(data)
        if i % 50000 == 0:
            _ = h.hexdigest()
    return h.hexdigest()


# ============================================================
# 7. JSON 序列化/反序列化
# ============================================================
def benchmark_json(iterations=50000):
    data = {
        "name": "benchmark",
        "values": [random.random() for _ in range(50)],
        "nested": {"a": 1, "b": [2, 3, 4], "c": {"d": "hello" * 20}},
    }
    total = 0
    for _ in range(iterations):
        s = json.dumps(data)
        d = json.loads(s)
        total += len(s)
    return total


# ============================================================
# 8. 字符串操作
# ============================================================
def benchmark_string(iterations=500):
    s = "Python CPU Benchmark " * 1000
    result = 0
    for _ in range(iterations):
        t = s.upper()
        t = t.lower().replace("python", "PYTHON")
        t = " ".join(t.split())
        result += len(t)
    return result


# ============================================================
# 9. 排序（百万级数据）
# ============================================================
def benchmark_sort(size=2000000):
    data = [random.random() for _ in range(size)]
    data.sort()
    return data[size // 2]


# ============================================================
# 主程序
# ============================================================
if __name__ == "__main__":
    random.seed(42)

    tests = [
        ("整数运算 (2亿次)",          benchmark_integer),
        ("浮点运算 (10^6 次三角函数)", benchmark_float),
        ("质数筛 (2000万以内)",       benchmark_prime_sieve),
        ("递归斐波那契 (n=38)",       benchmark_fibonacci),
        ("矩阵乘法 (200x200)",        benchmark_matrix),
        ("SHA-256 哈希 (20万次)",     benchmark_hash),
        ("JSON 序列化 (5万次)",       benchmark_json),
        ("字符串操作 (500次大文本)",  benchmark_string),
        ("排序 (200万元素)",          benchmark_sort),
    ]

    print("=" * 55)
    print("  CPU 单核性能基准测试 (Pure Python)")
    print("=" * 55)
    print()

    total = 0.0
    results = []

    for name, func in tests:
        print(f"  [运行] {name}...", end=" ", flush=True)
        start = time.time()
        func()
        elapsed = time.time() - start
        total += elapsed
        results.append((name, elapsed))
        print(f"{elapsed:.3f}s")

    # 计算字符串的终端显示宽度（中日韩字符占 2 列）
    def display_width(s):
        w = 0
        for ch in s:
            if '\u4e00' <= ch <= '\u9fff' or '\u3000' <= ch <= '\u303f' or '\uff00' <= ch <= '\uffef':
                w += 2
            else:
                w += 1
        return w

    def pad_to(s, target_width):
        dw = display_width(s)
        return s + ' ' * (target_width - dw) if dw < target_width else s

    # 找最长测试名宽度
    max_name_w = max(display_width(name) for name, _ in results) + 4

    print()
    print("-" * 60)
    for name, elapsed in results:
        pct = (elapsed / total) * 100
        bar = "#" * int(pct / 2)
        print(f"  {pad_to(name, max_name_w)} {elapsed:8.3f}s  {bar}")
    print("-" * 60)
    print(f"  总耗时: {total:.3f}s")
    print("=" * 60)
