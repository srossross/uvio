
from . import net

class TLSStream:
    pass

async def connect(host, port, cert=None, key=None, ca_list=None):
    socket = await net.connect(host, port)
    return TLSStream(socket)


def tls_handler(handler):
    return handler


async def listen(handler, host, port, backlog=511):

    server = net.Server(await get_current_loop(), tls_handler(handler))
    server.bind(host, port)
    server.listen(backlog)
    return server

