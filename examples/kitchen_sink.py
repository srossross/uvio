import uvio

PORT = 8888

async def get_random_number():

    p0 = await uvio.process.Popen([
        'python', '-c',
        'import random; print(random.randint(1000,10000))'
    ], stdout=uvio.process.PIPE)

    buf = b''

    @p0.stdout.data
    def get_data(data):
        nonlocal buf
        buf += data

    returncode = await p0.returncode

    return int(buf.decode())


def find_next_prime(lower, upper=None):
    print("find_next_prime", lower, upper)
    if upper is None:
        upper = 2 * lower

    for p in range(lower, upper):
        for i in range(2, p):
            if p % i == 0:
                break
        else:
            return p
    return None

async def prime_handler(socket):

    print("Handle Connection", socket)
    print("await socket.read(100)")

    @socket.data
    def data(buf):
        print("buf", buf)
        lower = int(buf.decode())
        uvio.worker(find_next_prime, lower)
        socket.write(b'1')

    @socket.end
    def end():
        print("end")
        socket.close()

@uvio.sync(timeout=10)
async def main():

    server = await uvio.net.listen(prime_handler, '127.0.0.1', PORT)

    print('Serving on {}'.format(server.getsockname()))

    socket = await uvio.net.connect('127.0.0.1', PORT)
    @socket.data
    def data(buf):
        print('result', buf)

    print("write...")
    await socket.write(b'10')
    print("shutdown...")
    await socket.shutdown()
    print("read ...")
    # reader = socket.read(100)
    # print("reader", reader)
    # value = await reader
    # loop = await uvio.get_current_loop()
    # @loop.next_tick
    # async def what():

    #     print("what?", reader)

    # print(value)
    # print('done')
    # uvio.net.listen()
    # # await uvio.set_timeout()
    # prime = await uvio.worker(find_next_prime, 10000000)

    # print(prime)

if __name__ == '__main__':
    main()
