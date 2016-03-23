import uvio

async def factorial(name, number):
    f = 1
    for i in range(2, number+1):
        print("Task %s: Compute factorial(%s)..." % (name, i))
        await uvio.sleep(1)
        f *= i
    print("Task %s: factorial(%s) = %s" % (name, number, f))


loop = uvio.get_default_loop()

loop.next_tick(factorial("A", 2))
loop.next_tick(factorial("B", 3))
loop.next_tick(factorial("C", 4))

loop.run()
loop.close()

