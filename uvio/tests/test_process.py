import signal
import unittest
import os
from contextlib import contextmanager
from functools import wraps
import sys
import uvio

from uvio.subprocess import ProcessOptions, Popen, PIPE
from uvio import sync
from uvio.pipes import Pipe
from inspect import iscoroutinefunction


class Test(unittest.TestCase):

    def test_options(self):

        opts = ProcessOptions(['echo', 'hello'], cwd='.')
        self.assertEqual(opts.cwd, '.')
        self.assertEqual(opts.executable, 'echo')
        self.assertEqual(opts.args, ['echo', 'hello'])

        del opts

    def test_stdio_option_pipe(self):

        pipe1 = Pipe()
        pipe2 = Pipe()
        pipe3 = Pipe()

        opts = ProcessOptions(['ok'], stdin=pipe1, stdout=pipe2, stderr=pipe3)

        self.assertIs(opts.stdin, pipe1)
        self.assertIs(opts.stdout, pipe2)

        self.assertIs(opts.stderr, pipe3)

    @sync(timeout=1)
    async def test_stdio_fd(self):

        with open("test.out", "w") as fd:
            p0 = await Popen(['python', '-c', 'print("hello")'], stdout=fd)
            self.assertEqual(await p0.returncode, 0)

        with open("test.out", "r") as fd:
            self.assertEqual(fd.read(), 'hello\n')



    @sync(timeout=1)
    async def test_stdout_env(self):

        stdout_captured = None
        stdout_ended = False
        p0 = await Popen(
            ['python', '-c', 'import os; print("env: {}".format(os.environ["FOOVAR"]))'],
            stdout=PIPE,
            env={"FOOVAR": "WOW!"}
        )

        self.assertIsNotNone(p0.stdout)
        self.assertIsNone(p0.stdin)
        self.assertIsNone(p0.stderr)

        @p0.stdout.data
        def data(buf):
            nonlocal stdout_captured
            stdout_captured = buf

        @p0.stdout.end
        def end():
            nonlocal stdout_ended
            stdout_ended = True

        self.assertEqual(await p0.returncode, 0)

        self.assertTrue(stdout_ended)
        self.assertEqual(stdout_captured, b'env: WOW!\n')


    @sync(timeout=1)
    async def test_stdout_pipe(self):

        stdout_captured = None
        stdout_ended = False
        p0 = await Popen(['python', '-c', 'print("hello")'], stdout=PIPE)

        self.assertIsNotNone(p0.stdout)
        self.assertIsNone(p0.stdin)
        self.assertIsNone(p0.stderr)

        @p0.stdout.data
        def data(buf):
            nonlocal stdout_captured
            stdout_captured = buf

        @p0.stdout.end
        def end():
            nonlocal stdout_ended
            stdout_ended = True

        self.assertEqual(await p0.returncode, 0)

        self.assertTrue(stdout_ended)
        self.assertEqual(stdout_captured, b'hello\n')


    @sync(timeout=1)
    async def test_stderr_pipe(self):

        stderr_captured = None
        stderr_ended = False
        p0 = await Popen(['python', '-c', 'import sys; print("hello", file=sys.stderr)'], stderr=PIPE)

        self.assertIsNotNone(p0.stderr)
        self.assertIsNone(p0.stdout)
        self.assertIsNone(p0.stdin)


        @p0.stderr.data
        def data(buf):
            nonlocal stderr_captured
            stderr_captured = buf

        @p0.stderr.end
        def end():
            nonlocal stderr_ended
            stderr_ended = True


        self.assertEqual(await p0.returncode, 0)

        self.assertTrue(stderr_ended)
        self.assertEqual(stderr_captured, b'hello\n')


    @sync(timeout=1)
    async def test_stdio_pipe(self):

        stdout_captured = None
        stdout_ended = False

        p0 = await Popen(
            ['python', '-c', 'import sys; print("echo: +{}+".format(sys.stdin.read()))'],
            stdin=PIPE, stdout=PIPE, stderr=sys.stderr
        )

        self.assertIsNotNone(p0.stdout)
        self.assertIsNotNone(p0.stdin)
        self.assertIsNone(p0.stderr)

        @p0.stdout.data
        def data(buf):
            nonlocal stdout_captured
            stdout_captured = buf

        @p0.stdout.end
        def end():
            nonlocal stdout_ended
            stdout_ended = True

        p0.stdin.write(b"write me")
        p0.stdin.close()

        self.assertEqual(await p0.returncode, 0)

        self.assertTrue(stdout_ended)
        self.assertEqual(stdout_captured, b'echo: +write me+\n')

    @sync(timeout=1)
    async def test_simple(self):

        p0 = await Popen(['python', '-c', 'print("hello")'])
        self.assertEqual(await p0.returncode, 0)

    @sync(timeout=1)
    async def test_exit_status(self):

        p0 = await Popen(['python', '-c', 'exit(17)'])
        self.assertEqual(await p0.returncode, 17)


    @sync(timeout=1)
    async def test_kill(self):

        p0 = await Popen(['python', '-c', 'import time; time.sleep(12)'])
        await uvio.sleep(.1)
        p0.kill()

        self.assertEqual(await p0.returncode, 0)


    @sync(timeout=1)
    async def test_interupt(self):

        p0 = await Popen(['python', '-c', 'import time; time.sleep(17)'], stdout=sys.stderr, stderr=sys.stderr)
        await uvio.sleep(.1)
        p0.kill(signal.SIGINT)
        rc = p0.returncode
        self.assertEqual(await rc, 1)



if __name__ == '__main__':
    unittest.main()

