
import uvio
from pprint import pprint

async def parse_headers(stream):

    firstline = await stream.readline()
    firstline = firstline.decode('latin1')
    headers = {}
    http_version, method, path = firstline.strip().split(maxsplit=2)


    while True:
        line = await stream.readline()

    # async for line in stream.readlines():

        if line == b'\r\n':
            break

        line = line.decode('latin1')
        key, value = line.strip().split(':', 1)
        headers[key] = value



    return http_version, method, path, headers

@uvio.sync
async def main():

    socket = await uvio.net.connect(host='google.com', port=80)

    socket.write(b"GET / HTTP/1.1\r\n\r\n")
    await socket.shutdown() # close for writing

    http_version, method, path, headers = await parse_headers(socket)
    print(http_version, method, path)

    pprint(headers)

    print('Content-Length', int(headers['Content-Length']))
    content_length = int(headers['Content-Length'])

    reader = socket.read(content_length)

    data = await reader

    print('data |||', data.decode('UTF-8').replace('\n', '\ndata ||| '))



if __name__ == '__main__':
    main()