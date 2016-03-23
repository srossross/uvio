import uvio.net

from urllib.parse import urlparse

class ClientRequest:
    def __init__(self, url, socket):
        self.url = url
        self.socket = socket


async def connect(target):

    url = urlparse(target)
    assert url.scheme == 'http'

    socket = await uvio.net.connect(url.netloc, 80)

    return ClientRequest(url, socket)

