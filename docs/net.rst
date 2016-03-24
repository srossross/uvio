Network
=======================


Network examples
-----------------


TCP echo client
^^^^^^^^^^^^^^^^

example ::

    import uvio

    message = 'Hello World!'

    def handler(socket):

    loop = asyncio.get_event_loop()
    message = 'Hello World!'

    @uvio.sync
    async def main():

        socket = await uvio.net.connect('127.0.0.1', 8888)

        socket.write(message.encode())
        print('Data sent: {!r}'.format(self.message))

        @socket.data
        def data_received(data):
            print('Data received: {!r}'.format(data.decode()))

        @socket.end
        def connection_lost():
            print('The server closed the connection')
            print('Stop the event loop')
            socket.close()


TCP echo server
^^^^^^^^^^^^^^^^

example ::

    import uvio

    async def handler(socket):

        print('Connection from {}'.format(socket.peername()))

        @socket.data
        def data_received(data):
            message = data.decode()
            print('Data received: {!r}'.format(message))

            print('Send: {!r}'.format(message))
            socket.write(data)

            print('Close the client socket')
            socket.close()

    @uvio.sync
    async def main():
        # Each client connection will create a new protocol instance
        server = await uvio.net.listen(handler, '127.0.0.1', 8888)

        print('Serving on {}'.format(server.getsockname()))



Get HTTP Headers
^^^^^^^^^^^^^^^^

example::

    import uvio
    import urllib.parse
    import sys

    @uvio.sync(timeout=3.0)
    async def print_http_headers(url):
        url = urllib.parse.urlsplit(url)
        if url.scheme == 'https':
            # Not implemented
            raise NotImplementedError("https")
        else:
            socket = await uvio.net.connect(url.hostname, 80)

        query = ('HEAD {path} HTTP/1.0\r\n'
                 'Host: {hostname}\r\n'
                 '\r\n').format(path=url.path or '/', hostname=url.hostname)

        writer.write(query.encode('latin-1'))
        while True:
            line = await socket.readline()
            if not line:
                break
            line = line.decode('latin1').rstrip()
            if line:
                print('HTTP header> %s' % line)

        # Ignore the body, close the socket
        socket.close()

    def main():
        url = sys.argv[1]
        print_http_headers(url)


