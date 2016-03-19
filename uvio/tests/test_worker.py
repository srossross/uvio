
import unittest

from uvio.loop import Loop
from uvio.workers import worker
import time

class Test(unittest.TestCase):

    def test_simple_worker(self):

        called = False
        blocking_called = False
        another_called = 0

        def blocking(arg):
            nonlocal blocking_called
            blocking_called = True
            time.sleep(0.05) # This is not an async sleep!
            return "Hello: {}".format(arg)


        async def callback():
            nonlocal called
            worker1 = worker(blocking, "Tester")
            result = await worker1

            self.assertEqual(result, "Hello: Tester")
            called = True

        loop = Loop.create()
        future = loop.next_tick(callback())

        loop.run()

        self.assertTrue(called)

    def test_blocking_worker(self):

        called = False
        another_called = 0

        def blocking(arg):
            time.sleep(0.05) # This is not an async sleep!
            return "Hello: {}".format(arg)


        async def callback():
            nonlocal called
            loop.next_tick(another_callback)
            result = await worker(blocking, "Tester")
            self.assertTrue(another_called)
            self.assertEqual(result, "Hello: Tester")
            called=True

        def another_callback():
            nonlocal another_called
            another_called = True

        loop = Loop.create()
        loop.next_tick(callback())

        loop.run()

        self.assertTrue(called)

    def test_worker_exception(self):

        called = False
        another_called = 0

        def blocking(arg):
            time.sleep(0.05) # This is not an async sleep!
            raise TypeError("belch")

        async def callback():
            nonlocal called
            loop.next_tick(another_callback)

            with self.assertRaises(TypeError):
                await worker(blocking, "Tester")

            called = True


        def another_callback():
            nonlocal another_called
            another_called = True

        loop = Loop.create()
        loop.next_tick(callback())

        loop.run()

        self.assertTrue(called)




    def test_multiple_workers(self):

        called = False

        running_list = [ ]
        # Check that the workers are not blocking
        runnung_in_parallel = False

        def blocking(arg, sleep_for=0.05):
            nonlocal runnung_in_parallel
            running_list.append(True)

            runnung_in_parallel = runnung_in_parallel or len(running_list) > 1

            time.sleep(sleep_for) # This is not an async sleep!
            running_list.pop(0)
            return "Hello: {}".format(arg)


        async def callback():
            nonlocal called

            worker1 = worker(blocking, "Tester1", sleep_for=0.1)
            worker2 = worker(blocking, "Tester2", sleep_for=0.05)

            worker1.start(loop)
            worker2.start(loop)

            result1 = await worker1
            result2 = await worker2

            self.assertEqual(result1, "Hello: Tester1")
            self.assertEqual(result2, "Hello: Tester2")
            called = True

        loop = Loop.create()
        future = loop.next_tick(callback())

        loop.run()

        self.assertTrue(called)
        self.assertTrue(runnung_in_parallel)
        self.assertEqual(len(running_list), 0)


if __name__ == '__main__':
    unittest.main()

