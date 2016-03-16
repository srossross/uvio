
import unittest
import os
from contextlib import contextmanager
from functools import wraps
import sys
import uvio

from uvio import run
from uvio.loop import Loop
from uvio.pipes import Pipe, connect, listen


class Test(unittest.TestCase):

    @uvio.run(timeout=1)
    async def test_pipe_connect(self):

        async def handler( client):

            @client.data
            def echo(buf):
                client.write(b"echo: " + buf)

            client.resume()


        async def connection():
            client = await uvio.pipes.connect("x.sock")

            @client.data
            def echo(buf):
                client.close()
                server.close()

            await client.write(b"this is a test")

            client.shutdown()

        server = await uvio.pipes.listen(handler, "x.sock")
        await connection()



if __name__ == '__main__':
    unittest.main()


