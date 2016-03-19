import unittest


from uvio.loop import Loop
from uvio.timer import Timer, sleep
from uvio.handle import Handle

class Test(unittest.TestCase):

    def test_init(self):

        loop = Loop.create()

        called = False

        def callback():
            nonlocal called
            called = True

        timer = Timer(callback, 0.05)

        self.assertFalse(timer.is_active())

        timer.start(loop)

        self.assertTrue(timer.is_active())
        self.assertFalse(timer.closing())
        self.assertFalse(called)

        loop.run()

        self.assertTrue(called)


    def test_sleep(self):

        loop = Loop.create()

        called = False

        async def callback():
            nonlocal called
            print('calling')
            await sleep(.05)
            print('called')
            called = True

        loop.next_tick(callback())

        loop.run()

        self.assertTrue(called)


if __name__ == '__main__':
    unittest.main()

