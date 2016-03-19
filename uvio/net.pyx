from .uv cimport *
from ._loop cimport Loop
from .handle cimport Handle
from .request cimport Request

import inspect

from .stream import Stream
from .loop import get_current_loop
from .futures import Future

cdef void connect_callback(uv_connect_t* _req, int status) with gil:
    if _req.data:
        req = <object> _req.data
    req.completed(status)


class TCP(Stream):

    def __init__(Handle self, Loop loop):

        Stream.__init__(self)
        uv_tcp_init(loop.uv_loop, &self.handle.tcp)

    def bind(Handle self, host, port):

        cdef Loop loop = self.loop

        cdef sockaddr_in addr
        uv_ip4_addr(host.encode(), port, &addr);

        failure = uv_tcp_bind(&self.handle.tcp, <const sockaddr*> &addr, 0);

        if failure:
            msg = "Bind error: {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

class Server(TCP):

    def __init__(self, loop, handler):
        self._handler = handler
        TCP.__init__(self, loop)

    def get_client(Handle self):
        return TCP(self.loop)



async def listen(handler, host, port, backlog=511):
    server = Server(await get_current_loop(), handler)
    server.bind(host, port)
    server.listen(backlog)
    return server


class connect(Request, Future):

    def __init__(self, host, port):
        self.host = host
        self.port = port

    def __uv_init__(Request self, Loop loop):

        cdef Handle client = TCP(loop)

        cdef sockaddr_in addr
        uv_ip4_addr(self.host.encode(), self.port, &addr);

        self.req.req.data = <void*> self

        failure = uv_tcp_connect(
            &self.req.connect,
            &client.handle.tcp,
            <const sockaddr*> &addr,
            connect_callback
        )

        self._result = client

    def result(self):
        "call resume before returning result"
        if self.done():
            self._result.resume()

        return self._result


    def __uv_complete__(self, status):
        if status < 0:
            msg = "Connect error: {}".format(uv_strerror(status).decode())
            self._exception = IOError(status,  msg)
        self._done = True



