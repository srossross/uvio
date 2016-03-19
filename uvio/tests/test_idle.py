import unittest

from uvio.loop import Loop
from uvio.idle import Idle
from uvio.handle import Handle

class Test(unittest.TestCase):

    def test_init(self):

        loop = Loop.create()

        called = False

        def callback():
            print("callback called!")
            nonlocal called
            called = True
            idle.stop()

        print("idle")
        idle = Idle(callback)

        self.assertFalse(idle.is_active())

        idle.start(loop)

        self.assertTrue(idle.is_active())
        self.assertFalse(idle.closing())
        self.assertFalse(called)

        print("run")
        loop.run()

        self.assertTrue(called)



if __name__ == '__main__':
    unittest.main()

