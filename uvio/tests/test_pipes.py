
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

        print("how")
        pipe = await Pipe()
        print("pipe")
        pipe.bind("local")

        pipe.close()

        print("got here", pipe)

        # pipe2 = await Pipe.connect("local")

        # print("pipe2", pipe2)

if __name__ == '__main__':
    unittest.main()


