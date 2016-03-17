import unittest

from uvio import run
from uvio.futures import Future

class F(Future):
    _is_active = False

    def is_active(self):
        return self._is_active

    def __uv_start__(self, loop):
        self._result = 'ok'
        self._is_active = True
        if self._coro:
            loop.next_tick(self._coro)

class Test(unittest.TestCase):

    @run(timeout=2.0)
    async def test_future(self):

        ok = await F()
        self.assertEqual("ok", ok)




if __name__ == '__main__':
    unittest.main()


