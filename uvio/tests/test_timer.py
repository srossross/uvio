import unittest

from uvio.loop import Loop
from uvio.timer import Timer
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
        self.assertFalse(timer.is_closing())
        self.assertFalse(called)

        loop.run()

        self.assertTrue(called)


if __name__ == '__main__':
    unittest.main()

