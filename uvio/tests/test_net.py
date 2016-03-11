import unittest

from uvio.loop import Loop
import uvio
from uvio.net import Connect

import time
class Test(unittest.TestCase):

    def test_client_connect_failure(self):

        async def connection():
            with self.assertRaises(IOError):
                await uvio.net.Connect("doesnotexist.net.doesnotexist", 80)

        loop = Loop.create()
        loop.next_tick(connection())
        loop.run()

    def test_server_connect(self):

        async def handle(server, client):
            print("handle!")
            buf = await client.read(3)
            print("client.read buf", buf)

        server = uvio.net.Server(handle)
        loop = Loop.create()

        server.listen(loop, "127.0.0.1", 8281)


        async def connection():
            print("start connection")
            client = await uvio.net.Connect("127.0.0.1", 8281)
            print("connected", client)
            print("is_closing", client.is_closing())
            print("is_active", client.is_active())
            print("await write",  await client.write(b"buf"))
            client.close()

            print("closed")


        def hello():
            print("hello")
            server.close()

        loop.next_tick(connection())
        loop.set_timeout(hello, 1)

        loop.run()

    @unittest.skip('na')
    def test_client_connect(self):

        async def connection():
            client = uvio.net.Connect("google.com", 80)

            @client.data
            def client_data(client, data):
                pass

            @client.end
            def client_end(client, status):
                pass

            print ("connect")
            await client
            print ("connected")


        loop = Loop.create()
        loop.next_tick(connection())
        loop.run()





if __name__ == '__main__':
    unittest.main()

