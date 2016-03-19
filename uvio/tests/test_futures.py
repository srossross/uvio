import unittest

from uvio import run
from uvio.futures import Future

class F(Future):
    _is_active = False

    def start(self, loop):
        self._done = True
        self._result = 'ok'


class Err(Future):
    _is_active = False

    def start(self, loop):
        self._done = True
        self._exception = TypeError("what?")

class Test(unittest.TestCase):

    @run(timeout=2.0)
    async def test_future(self):

        ok = await F()
        self.assertEqual("ok", ok)


    @run(timeout=2.0)
    async def test_error(self):

        with self.assertRaises(TypeError):
            await Err()





if __name__ == '__main__':
    unittest.main()


