import unittest

import uvio
class Test(unittest.TestCase):

    def test_sleep(self):

        loop = uvio.Loop.create()

        calls = []

        def callback():
            calls.append("callback")

        async def sleepy():
            calls.append("sleepy")
            loop.next_tick(callback)
            calls.append("sleep")
            await uvio.sleep(0.05)
            calls.append("done sleepy")

        loop.next_tick(sleepy())

        loop.run()
        self.assertEqual(calls, ['sleepy', 'sleep', 'callback', 'done sleepy'])






if __name__ == '__main__':
    unittest.main()

