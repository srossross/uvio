
import uvio

async def parse_headers(stream):

    firstline = await stream.readline()
    firstline = firstline.decode('latin1')
    headers = {}
    http_version, method, path = firstline.strip().split(maxsplit=2)
    print("firstline", repr((http_version, method, path)))

    while True:
        line = await stream.readline()

    # async for line in stream.readlines():
        print("|| line", line)
        print('|| stream._read_buffer', stream._read_buffer)

        if line == b'\r\n':
            break

        line = line.decode('latin1')
        key, value = line.strip().split(':', 1)
        headers[key] = value

    print('|| stream._read_buffer', stream._read_buffer)

    return http_version, method, path, headers

@uvio.sync
async def main():
    print("main")
    socket = await uvio.net.connect(host='google.com', port=80)
    print("socket", socket)
    @socket.data
    def on_data(buf):
        print(buf)

    socket.write(b"GET / HTTP/1.1\r\n\r\n")
    # print
    # await socket.shutdown() # close for writing
    print("shutdown")

    http_version, method, path, headers = await parse_headers(socket)
    print(http_version, method, path, headers)

    print(int(headers['Content-Length']))
    content_length = int(headers['Content-Length'])

    print('||++ stream._read_buffer', len(socket._read_buffer), socket._read_buffer)

    reader = socket.read(content_length)

    import pdb; pdb.set_trace()
    print("reader",reader.done())
    print("socket", socket)
    print("reader", reader)
    data = await reader



if __name__ == '__main__':
    main()