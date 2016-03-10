from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .stream cimport Stream
from .loop cimport Loop

import inspect
import asyncio

cdef void uv_python_on_connect(uv_connect_t* client, int status) with gil:
    pass

cdef void uv_python_on_new_connection(uv_stream_t* server, int status) with gil:

    if status < 0:
        raise IOError(status,  "New connection error {}".format(uv_strerror(status).decode()))
        return


    cdef Stream stream = Stream()
    cdef uv_tcp_t *client = <uv_tcp_t*> malloc(sizeof(uv_tcp_t));
    # uv_tcp_init(loop, client);
    # if (uv_accept(server, (uv_stream_t*) client) == 0) {
    #     uv_read_start((uv_stream_t*) client, alloc_buffer, echo_read);
    # }
    # else {
    #     uv_close((uv_handle_t*) client, NULL);
    # }
    # print("uv_python_on_new_connection")

    pass


cdef class Server(Stream):

    def __init__(self, Loop loop):

        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_tcp_t));

        uv_tcp_init(loop.uv_loop, <uv_tcp_t*> self.uv_handle);

    def listen(self, host, port, backlog=511):

        cdef sockaddr_in addr
        uv_ip4_addr(host.encode(), port, &addr);

        uv_tcp_bind( <uv_tcp_t*> self.uv_handle, <const sockaddr*> &addr, 0);

        failure = uv_listen(<uv_stream_t*> self.uv_handle, backlog, uv_python_on_new_connection);
        if failure:
            raise IOError(failure,  "Listen error {}".format(uv_strerror(failure).decode()))


# Request?
cdef class Client:
    cdef uv_connect_t* uv_connect
    cpdef object _end
    cpdef object _data

    def data(self, coro_func):
        self._data = coro_func

    def end(self, coro_func):
        self._end = coro_func


    @asyncio.coroutine
    @classmethod
    def connect(cls, Loop loop, host, port):

        cdef Client client = cls()

        cdef uv_tcp_t* socket = <uv_tcp_t *> malloc(sizeof(uv_tcp_t))
        uv_tcp_init(loop.uv_loop, socket);


        cdef sockaddr_in addr
        uv_ip4_addr(host.encode(), port, &addr);

        client.uv_connect = <uv_connect_t *> malloc(sizeof(uv_connect_t))

        uv_tcp_connect(client.uv_connect, socket, <const sockaddr*> &addr, uv_python_on_connect)

        yield client

        # return client

