import unittest

from uvio.loop import Loop
from uvio.idle import Idle
from uvio.handle import Handle

class Test(unittest.TestCase):

    def test_init(self):

        loop = Loop.create()

        called = False

        def callback():
            print("callback")
            nonlocal called
            called = True

        idle = Idle(callback)

        self.assertFalse(idle.is_active())

        print("idle._cpointer",idle._cpointer)
        print("start")
        idle.start(loop)

        print("idle._cpointer",idle._cpointer)

        self.assertTrue(idle.is_active())
        self.assertFalse(idle.is_closing())
        self.assertFalse(called)

        print("run")
        loop.run()
        print("done")

        self.assertTrue(called)



if __name__ == '__main__':
    unittest.main()

