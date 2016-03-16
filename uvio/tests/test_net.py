import unittest

from uvio.loop import Loop
import uvio
from uvio.net import connect

import time
class Test(unittest.TestCase):

    def test_client_connect_failure(self):

        async def connection():
            with self.assertRaises(IOError):
                await connect("doesnotexist.net.doesnotexist", 80)

        loop = Loop.create()
        loop.next_tick(connection())
        loop.run()

    @uvio.run(timeout=1)
    async def test_server_connect(self):

        async def handler(server, client):

            @client.data
            def echo(buf):
                print("on data:", buf)
                client.write(b"echo: " + buf)

            @client.end
            def end():
                print("on client end")

            client.resume()

            print("handle! server", server)
            print("handle! client", client)

        async def connection():
            print("start connection")
            client = await connect("127.0.0.1", 8281)

            @client.data
            def echo(buf):
                print("echoed:", buf)
                client.close()
                server.close()

            print("connected", client)
            print("is_closing", client.closing())
            print("is_active", client.is_active())


            print("client connection", client)
            await client.write(b"this is a test")

            client.shutdown()


        server = await uvio.net.listen(handler, "127.0.0.1", 8281)
        print("Server", server)
        await connection()

    @unittest.skip('na')
    def test_client_connect(self):

        async def connection():
            client = connect("google.com", 80)

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

