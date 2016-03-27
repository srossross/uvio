Coroutines
==========

Coroutines Examples
---------------------


Parallel execution of tasks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Example ::

    import uvio
    from datetime import datetime

    @uvio.sync
    async def display_date():
        end_time = datetime.now() + timedelta(seconds=5)
        while True:
            print(datetime.now())
            if (datetime.now() + timedelta(seconds=5)) >= end_time:
                break
            await uvio.sleep(1)

    display_date()


Parallel execution of tasks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Example executing 3 tasks (A, B, C) in parallel::

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



