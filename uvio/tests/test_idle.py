import unittest

from uvio.loop import Loop
from uvio.idle import Idle
from uvio.handle import Handle

class Test(unittest.TestCase):

    def test_init(self):

        loop = Loop.create()

        called = False

        def callback():
            nonlocal called
            called = True

        idle = Idle()

        self.assertFalse(idle.is_active())

        idle.start(loop, callback)

        self.assertTrue(idle.is_active())
        self.assertFalse(idle.is_closing())
        self.assertFalse(called)

        loop.run()

        self.assertTrue(called)



if __name__ == '__main__':
    unittest.main()

