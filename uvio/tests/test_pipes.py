
import unittest
import os
from contextlib import contextmanager
from functools import wraps
import sys
import uvio

from uvio import run
from uvio.loop import Loop
from uvio.stream import Pipe


class Test(unittest.TestCase):

    @run(timeout=1)
    async def test_connect_bind(self):

        pipe1 = await Pipe()
        pipe1.bind("./local.sock")

        pipe2 = await Pipe()
        await pipe2.connect("./local.sock")

        print("pipe1", pipe1)
        print("pipe2", pipe2)
        await pipe1.write(b'hello')
        print(await pipe.read(5))

        pipe1.close()
        pipe2.close()

        # print("pipe2", pipe2)

if __name__ == '__main__':
    unittest.main()


