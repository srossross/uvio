from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle
from .request cimport Request

from .stream import Stream

import inspect

from .futures import Future

cdef void uv_python_on_connect(uv_connect_t* req, int status) with gil:

    if status < 0:
        network_error = IOError(status, "Network Connection error: {}".format(uv_strerror(status).decode()))
    else:
        network_error = None

    connect = <object> req.data


    try:
        connect.set_completed(network_error)
    except BaseException as err:

        loop = <object> req.handle.loop.data
        loop.catch(err)

    Py_DECREF(connect)


cdef void uv_python_on_new_connection(uv_stream_t* stream, int status) with gil:

    if status < 0:
        network_error = IOError(status, "Cound not create new connection: {}".format(uv_strerror(status).decode()))
    else:
        network_error = None

    server = <object> stream.data

    try:
        server.accept()
    except BaseException as err:
        loop = <object> stream.loop.data
        loop.catch(err)


class TCP(Stream):
    pass

class Server(TCP):

    def __init__(self, handler):
        self.handler = handler

    def accept(Handle self):

        cdef Handle client = Stream()

        uv_tcp_init(self.handle.handle.loop, &client.handle.tcp)

        failure = uv_accept(&self.handle.stream, &client.handle.stream)

        if failure:
            client.close()
            msg = "Accept error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)
        else:
            self.loop.next_tick(self.handler(self, client))

    def listen(Handle self, Loop loop, host, port, backlog=511):


        uv_tcp_init(loop.uv_loop, &self.handle.tcp);

        cdef sockaddr_in addr
        uv_ip4_addr(host.encode(), port, &addr);

        uv_tcp_bind(&self.handle.tcp, <const sockaddr*> &addr, 0);

        failure = uv_listen(&self.handle.stream, backlog, uv_python_on_new_connection);

        if failure:
            msg = "Listen error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

        self.handle.handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)


cdef class _Connect(Request):
    property loop:
        def __get__(self):
            return <object> self.req.connect.handle.loop.data


class connect(_Connect, Future):

    def __init__(self, host, port):
        self.host = host
        self.port = port

    def _uv_start(_Connect self, Loop loop):

        cdef Handle client = TCP()

        uv_tcp_init(loop.uv_loop, &client.handle.tcp);

        cdef sockaddr_in addr
        uv_ip4_addr(self.host.encode(), self.port, &addr);

        self.req.req.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        failure = uv_tcp_connect(
            &self.req.connect,
            &client.handle.tcp,
            <const sockaddr*> &addr,
            uv_python_on_connect
        )

        self._result = client

    def set_completed(self, err):

        if not err:
            self._result.resume()

        Future.set_completed(self, err)



