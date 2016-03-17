from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle
from .request cimport Request

from .stream import Stream
from .loop import get_current_loop
import inspect

from .futures import Future

cdef void connect_callback(uv_connect_t* req, int status) with gil:
    request = <object> req.data
    loop = <object> req.handle.loop.data
    loop.connect_callback(request, status)


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

    def accept(Handle self):

        cdef Handle client = self.get_client()

        failure = uv_accept(&self.handle.stream, &client.handle.stream)

        if failure:
            client.close()
            msg = "Accept error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)
        else:
            self.loop.next_tick(self._handler(self, client))


async def listen(handler, host, port, backlog=511):
    server = Server(await get_current_loop(), handler)
    server.bind(host, port)
    server.listen(backlog)
    return server


class connect(Request, Future):


    def __init__(self, host, port):
        self.host = host
        self.port = port

    @property
    def loop(Request self):
        return <object> self.req.connect.handle.loop.data

    def __uv_start__(Request self, Loop loop):

        cdef Handle client = TCP(loop)

        cdef sockaddr_in addr
        uv_ip4_addr(self.host.encode(), self.port, &addr);

        self.req.req.data = <void*> (<PyObject*> self)
        loop._add_req(self)

        failure = uv_tcp_connect(
            &self.req.connect,
            &client.handle.tcp,
            <const sockaddr*> &addr,
            connect_callback
        )

        self._result = client

    def set_completed(self, err):

        if not err:
            self._result.resume()

        Future.set_completed(self, err)



