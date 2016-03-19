from pprint import pprint
import unittest
import os
from contextlib import contextmanager
from functools import wraps
import sys
import uvio

from uvio import run
from uvio.loop import Loop, get_current_loop
from uvio.pipes import Pipe, connect, listen


class Test(unittest.TestCase):

    @uvio.run(timeout=1)
    async def test_read_write(self):

        cleanup = lambda: os.path.exists('x.sock') and os.unlink('x.sock')
        cleanup()
        self.addCleanup(cleanup)

        data_recieved = False

        async def handler(socket):

            @socket.data
            def echo(buf):
                nonlocal data_recieved
                data_recieved = buf
                socket.close()
                client.close()
                server.close()


        server = await uvio.pipes.listen(handler, "x.sock")
        client = await uvio.pipes.connect("x.sock")
        await client.write(b"this is a test")


        self.assertEqual(b'this is a test', data_recieved)


    @uvio.run(timeout=1)
    async def test_echo(self):

        cleanup = lambda: os.path.exists('x.sock') and os.unlink('x.sock')
        cleanup()
        self.addCleanup(cleanup)

        async def handler(socket):

            @socket.data
            def echo(buf):
                socket.write(b"echo: " + buf)
                socket.close()

        server = await uvio.pipes.listen(handler, "x.sock")


        client = await uvio.pipes.connect("x.sock")
        client.resume()
        print("client", client)

        data_echoed = None

        @client.data
        def echo(buf):
            nonlocal data_echoed
            data_echoed = buf
            print("client recvd data", buf)
            self.assertEqual(buf, b'echo: this is a test')
            client.close()
            server.close()

        await client.write(b"this is a test")



if __name__ == '__main__':
    unittest.main()


