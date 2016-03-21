from pprint import pprint
import unittest
import os
from contextlib import contextmanager
from functools import wraps
import sys
import uvio

from uvio import sync
from uvio.loop import Loop, get_current_loop
from uvio.pipes import Pipe, connect, listen


class Test(unittest.TestCase):

    @uvio.sync(timeout=1)
    async def test_read_write(self):

        cleanup = lambda: os.path.exists('x.sock') and os.unlink('x.sock')
        cleanup()
        self.addCleanup(cleanup)

        data_recieved = False

        async def handler(socket):
            socket.write(b"this is a test")
            socket.close()
            server.close()

        server = await uvio.pipes.listen(handler, "x.sock")

        client = await uvio.pipes.connect("x.sock")

        self.assertEqual(await client.read(1), b't')
        self.assertEqual(await client.read(3), b'his')

        self.assertEqual(await client.read(1000), b' is a test')



    @uvio.sync(timeout=1)
    async def test_read_line(self):

        cleanup = lambda: os.path.exists('x.sock') and os.unlink('x.sock')
        cleanup()
        self.addCleanup(cleanup)

        data_recieved = False

        async def handler(socket):
            socket.write(b"this is a test\nthis is another line\nyet another line")
            socket.close()
            server.close()

        server = await uvio.pipes.listen(handler, "x.sock")

        client = await uvio.pipes.connect("x.sock")


        self.assertEqual(await client.readline(), b'this is a test\n')
        readline = client.readline()

        self.assertEqual(await readline, b'this is another line\n')
        self.assertEqual(await client.readline(3), b'yet')
        self.assertEqual(await client.readline(end=b'th'), b' anoth')
        self.assertEqual(await client.readline(), b'er line')


    @uvio.sync(timeout=2)
    async def test_async_reader(self):

        cleanup = lambda: os.path.exists('x.sock') and os.unlink('x.sock')
        cleanup()
        self.addCleanup(cleanup)

        async def handler(socket):

            socket.write(b"some data")
            socket.close()
            server.close()

        server = await uvio.pipes.listen(handler, "x.sock")

        client = await uvio.pipes.connect("x.sock")

        @client.data
        async def client_data(buf):
            await uvio.sleep(.1)
            self.assertEqual(buf, b'some data')
            client.close()


    @uvio.sync(timeout=1)
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


        data_echoed = None

        @client.data
        def echo(buf):
            nonlocal data_echoed
            data_echoed = buf
            self.assertEqual(buf, b'echo: this is a test')
            client.close()
            server.close()

        await client.write(b"this is a test")



if __name__ == '__main__':
    unittest.main()


