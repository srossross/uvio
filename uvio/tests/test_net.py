import unittest

from uvio.loop import Loop
import uvio
from uvio.net import connect, getaddrinfo

import time
class Test(unittest.TestCase):

    def test_client_connect_failure(self):

        async def connection():
            with self.assertRaises(IOError):
                await connect("doesnotexist.net.doesnotexist", 80)

        loop = Loop.create()
        loop.next_tick(connection())
        loop.run()

    @uvio.sync(timeout=1)
    async def test_getaddrinfo_local(self):

        # print(await getaddrinfo("google.com"))
        addr = await getaddrinfo("127.0.0.1")
        self.assertEqual(repr(addr), '<SockAddrIn "127.0.0.1">')

    @uvio.sync(timeout=1)
    async def test_getaddrinfo(self):

        with self.assertRaises(IOError):
            await getaddrinfo("doesnotexist.net.doesnotexist")


    @uvio.sync(timeout=1)
    async def test_server_connect(self):

        async def handler(socket):

            @socket.data
            def echo(buf):
                print("server: on data", buf)
                socket.write(b"echo: " + buf)
                socket.close()

            @socket.end
            def end():
                print("on socket end")

            print("handle! socket", socket)


        async def connection():
            print("start connection")
            client = await connect("127.0.0.1", 8281)
            # client.resume()

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

            await client.shutdown()


        server = await uvio.net.listen(handler, "127.0.0.1", 8281)
        print("Server", server)
        await connection()

    @uvio.sync(timeout=2)
    async def test_client_connect(self):


            client = await connect("google.com", 80)

            @client.data
            def client_data(data):
                print("client_data",data)
                client.close()

            @client.end
            def client_end():
                print("end")

            await client.write(b'GET / HTTP/1.1\r\n\r\n')




if __name__ == '__main__':
    unittest.main()

