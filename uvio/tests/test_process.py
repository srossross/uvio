
import unittest
import os
from contextlib import contextmanager
from functools import wraps

import uvio

from uvio.subprocess import ProcessOptions, Popen, PIPE
from uvio.loop import Loop
from uvio.stream import Pipe
from inspect import iscoroutinefunction

def run_in_loop(func):

    @wraps(func)
    def inner(self):
        loop = Loop.create()

        if iscoroutinefunction(func):
            loop.next_tick(func(self))
        else:
            loop.next_tick(func)

        loop.run()

    return inner

class Test(unittest.TestCase):

    def test_options(self):

        opts = ProcessOptions(['echo', 'hello'], cwd='.')
        self.assertEqual(opts.cwd, '.')
        self.assertEqual(opts.executable, 'echo')
        self.assertEqual(opts.args, ['echo', 'hello'])

        del opts

    def test_stdio_option_pipe(self):

        stdout=Pipe()
        opts = ProcessOptions(['ok'], stdout=stdout)

        self.assertIs(opts.stdout, stdout)

    @run_in_loop
    async def test_stdio_fd(self):

        with open("test.out", "w") as fd:
            p0 = Popen(['python', '-c', 'print("hello")'], stdout=fd)
            self.assertEqual(await p0, 0)

        with open("test.out", "r") as fd:
            self.assertEqual(fd.read(), 'hello')

    @run_in_loop
    async def test_stdio_create_pipe(self):

        stdout_captured = None
        stdout_ended = False
        p0 = await Popen(['python', '-c', 'print("hello")'], stdout=PIPE)

        @p0.stdout.data
        def data(buf):
            nonlocal stdout_captured
            stdout_captured = buf

        @p0.stdout.end
        def end():
            nonlocal stdout_ended
            stdout_ended = True

        p0.stdout.resume()

        self.assertEqual(await p0.returncode, 0)

        self.assertTrue(stdout_ended)
        self.assertEqual(stdout_captured, b'hello\n')


    def test_stdio_create_pipe2(self):

        loop = Loop.create()

        def next_():
            print("still here!")
            # stdout.unref()

        stdout = Pipe()
        print('paused? 1', stdout.paused())
        # stdout.init(loop)

        p0 = Popen(['python', '-c', 'print("hello")'], stdout=stdout)

        print("start?")
        # stdout.start(loop)
        p0.start(loop)
        print("started")

        print('paused? 2', stdout.paused())

        @stdout.data
        def data(buf):
            print("!!!got this buf", buf)

        @stdout.end
        def end():
            print("!!!stream end")

        print('paused? 3', stdout.paused())

        print("resume")
        stdout.resume()

        print("lets go")

        async def cb():


            # p0.start(loop)
            print("ok?")
            print('p0.stdout', p0.stdout)


            p0.stdout.resume()
            print("done", await p0)

            # loop.next_tick(cb())

        loop.next_tick(cb())
        loop.set_timeout(next_, .5)
        loop.run()


    def test_simple(self):

        async def echo():

            p0 = Popen(['python', '-c', 'print("hello")'])
            self.assertEqual(await p0, 0)

        loop = Loop.create()
        loop.next_tick(echo())
        loop.run()

    def test_exit_status(self):

        async def echo():

            p0 = Popen(['python', '-c', 'exit(17)'])
            self.assertNotEqual(await p0, 0)

        loop = Loop.create()
        loop.next_tick(echo())
        loop.run()


if __name__ == '__main__':
    unittest.main()

