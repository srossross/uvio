Pipes
=====

Pipes are implemented as linux domain sockets or windows named pipes
depending on what system you are running on.

Pipe examples
-----------------


Pipe echo client
^^^^^^^^^^^^^^^^

example ::

    import uvio

    message = 'Hello World!'

    def handler(socket):

    loop = asyncio.get_event_loop()
    message = 'Hello World!'

    @uvio.sync
    async def main():

        socket = await uvio.pipes.connect('windows_pipe_or_unix_domain.sock')

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


Pipes echo server
^^^^^^^^^^^^^^^^^^

example ::

    import uvio

    async def handler(socket):

        print('Connection from {}'.format(socket.getpeername()))

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
        server = await uvio.pipes.listen(handler, 'windows_pipe_or_unix_domain.sock')

        print('Serving on {}'.format(server.getsockname()))


