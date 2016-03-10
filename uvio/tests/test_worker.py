
import unittest

from uvio.loop import Loop
import uvio
from uvio.handle import Handle

import time
class Test(unittest.TestCase):

    def test_blocking_worker(self):

        called = False
        another_called = 0

        def blocking(arg):
            time.sleep(0.05) # This is not an async sleep!
            return "Hello: {}".format(arg)


        async def callback():
            nonlocal called
            loop.next_tick(another_callback)
            result = await uvio.worker(blocking, "Tester")
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
                await uvio.worker(blocking, "Tester")

            called = True


        def another_callback():
            nonlocal another_called
            another_called = True

        loop = Loop.create()
        loop.next_tick(callback())

        loop.run()

        self.assertTrue(called)





if __name__ == '__main__':
    unittest.main()

