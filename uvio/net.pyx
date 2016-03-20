from cpython.bytes cimport PyBytes_FromStringAndSize

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

cdef void getaddrinfo_callback(uv_getaddrinfo_t* _req, int status, addrinfo* res) with gil:

    cdef SockAddrIn info = None

    if res and status >= 0:
        info = SockAddrIn()
        info._addr = (<sockaddr_in*> res.ai_addr)[0]


    if _req.data:
        req = <object> _req.data
        req.completed(status, info)


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



class Connect(Request, Future):

    def __init__(self, addr, port):
        if not isinstance(addr, SockAddrIn):
            raise TypeError("addr must be a type uvio.net.SockAddrIn (got: {})".format(type(addr)))

        self.addr = addr
        self.port = port

    def __uv_init__(Request self, Loop loop):

        cdef Handle client = TCP(loop)

        cdef SockAddrIn addr = self.addr

        self.req.req.data = <void*> self

        failure = uv_tcp_connect(
            &self.req.connect,
            &client.handle.tcp,
            <const sockaddr*> &addr._addr,
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



cdef class SockAddrIn:
    cdef sockaddr_in _addr

    def __repr__(self):
        cdef char addr[17];
        uv_ip4_name(&self._addr, addr,  16)
        return '<SockAddrIn "{}">'.format(addr.decode())


cdef class AddrInfo:
    cdef addrinfo _info

class getaddrinfo(Request, Future):

    def __init__(self, hostname, port=80):
        self.hostname = hostname
        self.port = port
        self.hints = AddrInfo()

    def __uv_init__(Request self, Loop loop):

        cdef AddrInfo hints = self.hints


        hints._info.ai_family = PF_INET
        hints._info.ai_socktype = SOCK_STREAM
        hints._info.ai_protocol = IPPROTO_TCP
        hints._info.ai_flags = 0

        status = uv_getaddrinfo(
            loop.uv_loop,
            &self.req.getaddrinfo,
            getaddrinfo_callback,
            self.hostname.encode(),
            str(self.port).encode(),
            &hints._info
        )

        if status < 0:
            msg = "DNS error: {}".format(uv_strerror(status).decode())
            raise IOError(status,  msg)


    def __uv_complete__(self, status, addr_info):
        self._done = True
        if status < 0:
            msg = "DNS error: {}".format(uv_strerror(status).decode())
            self._exception = IOError(status,  msg)
            return

        self._result = addr_info






async def listen(handler, host, port, backlog=511):
    server = Server(await get_current_loop(), handler)
    server.bind(host, port)
    server.listen(backlog)
    return server

async def connect(host, port):
    addr = await  getaddrinfo(host, port)
    return await Connect(addr, port)



