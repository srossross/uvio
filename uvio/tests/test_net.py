import unittest

from uvio.loop import Loop
import uvio
from uvio.net import Client

import time
class Test(unittest.TestCase):

    def test_client_connect(self):

        async def connection():
            client = uvio.net.Client()

            @client.data
            def client_data(client, data):
                pass

            @client.end
            def client_end(client, status):
                pass

            print ("connect")
            await client.connect(loop, "google.com", 80)


        loop = Loop.create()
        loop.next_tick(connection())
        loop.run()





if __name__ == '__main__':
    unittest.main()

