import uvio.net

from urllib.parse import urlparse

async def connect(target):

    url = urlparse(target)
    assert url.scheme == 'http'

    socket = await uvio.net.connect(url.netloc, 80)

    return ClientRequest(url, socket)

