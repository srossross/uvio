from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .stream cimport Stream
from .loop cimport Loop
from .request cimport Request

import inspect
import asyncio


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


class Server(Stream):

    def __init__(self, handle):
        self.handle = handle

    def accept(Stream self):

        cdef Stream client = Stream()
        client.uv_handle = <uv_handle_t*> malloc(sizeof(uv_tcp_t))

        uv_tcp_init(self.uv_handle.loop, <uv_tcp_t *> client.uv_handle)

        failure = uv_accept(<uv_stream_t*> self.uv_handle, <uv_stream_t*> client.uv_handle)

        if failure:
            client.close()
            msg = "Accept error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)
        else:
            self.loop.next_tick(self.handle(self, client))


    def listen(Stream self, Loop loop, host, port, backlog=511):

        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_tcp_t));
        uv_tcp_init(loop.uv_loop, <uv_tcp_t*> self.uv_handle);

        cdef sockaddr_in addr
        uv_ip4_addr(host.encode(), port, &addr);

        uv_tcp_bind( <uv_tcp_t*> self.uv_handle, <const sockaddr*> &addr, 0);

        failure = uv_listen(<uv_stream_t*> self.uv_handle, backlog, uv_python_on_new_connection);

        if failure:
            msg = "Listen error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

        self.uv_handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)




cdef class _Connect(Request):
    property loop:
        def __get__(self):
            return <object> (<uv_connect_t*> self.req).handle.loop.data

    def is_active(self):
        return <int> self.req



class Connect(_Connect, Future):

    def __init__(self, host, port):
        self.host = host
        self.port = port


    def is_active(_Connect self):
        return <int> self.req and not self._done

    def _uv_start(_Connect self, Loop loop):

        cdef Stream client = Stream()

        client.uv_handle = <uv_handle_t *> malloc(sizeof(uv_tcp_t))
        uv_tcp_init(loop.uv_loop, <uv_tcp_t *> client.uv_handle);

        cdef sockaddr_in addr
        uv_ip4_addr(self.host.encode(), self.port, &addr);

        self.req = <uv_req_t *> malloc(sizeof(uv_connect_t))

        self.req.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        failure = uv_tcp_connect(
            <uv_connect_t*> self.req,
            <uv_tcp_t *> client.uv_handle,
            <const sockaddr*> &addr,
            uv_python_on_connect
        )

        self._result = client


