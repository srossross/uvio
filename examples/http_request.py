
import uvio

async def parse_headers(stream):

    firstline = await stream.readline()
    firstline = firstline.decode()
    headers = {}
    http_version, method, path = firstline.strip().split()

    async for line in stream.readlines():
        if line == b'\r\n':
            break

        line = line.decode()
        key, value = line.strip().split(':')
        headers[key] = value

    return http_version, method, path, headers

@uvio.run
async def main():

    socket = await uvio.net.connect(host='google.com', port=80)

    socket.write(b"GET / HTTP/1.1\r\n\r\n")
    await socket.shutdown() # close for writing

    http_version, method, path, headers = await parse_headers(socket)

    data = await socket.read(headers['Content-Length'])



