
import unittest
import os

import uvio

from uvio import sync
from uvio.fs import open as uvopen, stream

test_data = os.path.join(os.path.dirname(__file__), 'data.txt')
class Test(unittest.TestCase):

    @sync(timeout=1)
    async def test_read(self):


        async with uvopen(test_data, "r") as fd:
            data = await fd.read()
            self.assertEqual(data, b"Hello World")
            self.assertEqual(b"", await fd.read(1))

        async with uvopen(test_data, "r") as fd:
            data = await fd.read(1)
            self.assertEqual(data, b"H")


    @sync(timeout=1)
    async def test_write(self):

        async with uvopen('test_write.txt', 'w') as fd:
            n = await fd.write(b"Hello World")


        with open('test_write.txt', 'r') as fd:
            data = fd.read()
            self.assertEqual(data, "Hello World")

    @unittest.skip('n/i')
    @sync(timeout=1.0)
    async def test_stream(self):

        fd1 = await uvio.fs.stream(test_data, 'r')
        # fd2 = await uvio.fs.stream('test_stream.txt', 'w')


        @fd1.data
        def data(buf):
            print('got', buf)
            #fd1.close()
            # fd2.write(buf)

        @fd1.end
        def end():
            print('end')
            # fd2.close()
            fd1.close()

        fd1.resume()

    @unittest.skip('n/i')
    @sync(timeout=1.0)
    async def test_stream_read(self):

        fd1 = await uvio.fs.stream(test_data, 'r')
        print("fd1", fd1)
        fd1.close()
        # fd2 = await uvio.fs.stream('test_stream.txt', 'w')


        # @fd1.data
        # def data(buf):
        #     print('got', buf)
        #     #fd1.close()
        #     # fd2.write(buf)

        # @fd1.end
        # def end():
        #     print('end')
        #     # fd2.close()
        #     fd1.close()

        # fd1.resume()


    @sync(timeout=1)
    async def test_fstat(self):


        async with uvopen(test_data, "r") as fd:
            stats = uvio.fs.fstat(fd)
            self.assertEqual(stats.st_size, 11)




if __name__ == '__main__':
    unittest.main()

