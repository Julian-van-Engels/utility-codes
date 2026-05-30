import time as time


def print_hi(name):
    print(f"Hi, {name}")


def calc_test():
    a = 0
    for i in range(10000):
        if (i % 100) == 0:
            print("aaaaaaaa {}".format(i))
        for j in range(100000):
            a += i * j
    print("the result of a is {}".format(a))


if __name__ == "__main__":
    print_hi('PyCharm')
    start = time.time()
    calc_test()
    end = time.time()
    print("total time: {}".format(end - start))
