
import unittest
import os
import uvio

test_data = os.path.join(os.path.dirname(__file__), 'data.txt')
class Test(unittest.TestCase):

    def test_read(self):

        loop = uvio.Loop.create()

        async def reader():

            with uvio.fs.open(loop, test_data, "r") as fd:
                data = await fd.read()
                self.assertEqual(data, "Hello World")

            with uvio.fs.open(loop, test_data, "r") as fd:
                data = await fd.read(1)
                self.assertEqual(data, "H")

        loop.next_tick(reader())

        loop.run()

    def test_fstat(self):

        loop = uvio.Loop.create()

        async def reader():

            with uvio.fs.open(loop, test_data, "r") as fd:
                stats = uvio.fs.fstat(fd)
                self.assertEqual(stats.st_size, 11)


        loop.next_tick(reader())

        loop.run()



if __name__ == '__main__':
    unittest.main()

