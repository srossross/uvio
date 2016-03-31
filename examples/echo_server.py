import uvio

async def echo(server, socket):

    @socket.data
    def respond(buf):
        resp = b'Got:' + line
        socket.write(resp)

    @socket.end
    def end():
        socket.close()


@uvio.run
async def main(port=25000):
    server = await uvio.net.listen(echo, host='127.0.0.1', port=port)

    print("Server is now listening on port:", port)

    return


if __name__ == '__main__':
    main()
