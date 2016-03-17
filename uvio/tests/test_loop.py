import unittest

from uvio.loop import Loop, get_current_loop
from uvio.idle import Idle

class Test(unittest.TestCase):

    def test_default_loop(self):

        loop1 = Loop.get_default_loop()
        loop2 = Loop.get_default_loop()

        self.assertIs(loop1, loop2)

    def test_current_loop(self):
        loop = Loop.create()

        called = False

        async def callback():
            nonlocal called
            called = True
            self.assertIs(loop, await get_current_loop())

        loop.next_tick(callback())

        self.assertFalse(called)

        loop.run()
        loop.close()

        self.assertTrue(called)

    def test_next_tick(self):
        loop = Loop.create()

        called = False

        def callback():
            nonlocal called
            called = True

        loop.next_tick(callback)

        self.assertFalse(called)

        loop.run()
        loop.close()

        self.assertTrue(called)


    def test_unhandled_exception(self):

        loop = Loop.create()

        def callback():
            raise TypeError("what?")

        loop.next_tick(callback)

        with self.assertRaises(TypeError):

            loop.run()
        loop.close()

    def test_handle_exception(self):

        loop = Loop.create()

        handled = False
        def exception_handler(type, value, tb):

            nonlocal handled
            import traceback
            traceback.print_exception(type, value, tb)
            handled = True
            print(tb)

            print("exception_handler", value)

        loop.exception_handler = exception_handler

        def callback():
            raise TypeError("what?")

        called = False
        def timeout():
            print('timeout')
            nonlocal called
            called = True

        loop.next_tick(callback)
        loop.set_timeout(timeout, 0.002)

        loop.run()
        loop.close()

        self.assertTrue(called)
        self.assertTrue(handled)


    def test_reraise_exception(self):

        loop = Loop.create()

        def exception_handler(type, value, traceback):
            raise value

        loop.exception_handler = exception_handler

        def callback():
            raise TypeError("what?")

        called = False
        def timeout():
            nonlocal called
            called = True

        loop.next_tick(callback)
        loop.set_timeout(timeout, 0.05)

        with self.assertRaises(TypeError):
            loop.run()

        loop.close()

        self.assertFalse(called)

    def test_walk(self):
        loop = Loop.create()

        idle = Idle(loop, None)
        idle.start()

        handles = []

        @loop.walk
        def walk(handle):
            self.assertIs(handle, idle)
            handles.append(handle)

        self.assertEqual(len(handles), 1)



if __name__ == '__main__':
    unittest.main()


