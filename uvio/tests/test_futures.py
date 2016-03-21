import unittest

from uvio import sync
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

    @sync(timeout=2.0)
    async def test_future(self):

        ok = await F()
        self.assertEqual("ok", ok)


    @sync(timeout=2.0)
    async def test_error(self):

        with self.assertRaises(TypeError):
            await Err()





if __name__ == '__main__':
    unittest.main()


