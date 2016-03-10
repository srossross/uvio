from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .stream cimport Stream
from .loop cimport Loop

import inspect
import asyncio


from .futures import Future

cdef void uv_python_on_connect(uv_connect_t* req, int status) with gil:

    print("uv_python_on_connect")

    print("?status", status)
    if status < 0:

        network_error = IOError(status, "Network Connection error: {}".format(uv_strerror(status).decode()))
    else:
        network_error = None

    print("--", network_error)

    client = <object> req.data
    print("client", client)
    try:
        print("client set_completed")
        client.set_completed(network_error)
    except BaseException as err:
        print("Err", err)
        loop = <object> req.loop.data
        loop.catch(err)

    Py_DECREF(client)

    print("return from uv_python_on_connect")



cdef void uv_python_on_new_connection(uv_stream_t* server, int status) with gil:

    print("uv_python_on_new_connection")

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


class Server(Stream):

    def __init__(Stream self, Loop loop):

        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_tcp_t));

        uv_tcp_init(loop.uv_loop, <uv_tcp_t*> self.uv_handle);

    def listen(Stream self, host, port, backlog=511):

        cdef sockaddr_in addr
        uv_ip4_addr(host.encode(), port, &addr);

        uv_tcp_bind( <uv_tcp_t*> self.uv_handle, <const sockaddr*> &addr, 0);

        failure = uv_listen(<uv_stream_t*> self.uv_handle, backlog, uv_python_on_new_connection);
        if failure:
            raise IOError(failure,  "Listen error {}".format(uv_strerror(failure).decode()))


cdef class _Client:
    cdef uv_connect_t* uv_connect

class Client(_Client, Future):

    def __init__(self, host, port):
        self.host = host
        self.port = port

    def data(self, coro_func):
        self._data = coro_func

    def end(self, coro_func):
        self._end = coro_func

    def is_active(_Client self):
        return <int> self.uv_connect and not self._done

    def _uv_start(_Client self, Loop loop):

        cdef uv_tcp_t* socket = <uv_tcp_t *> malloc(sizeof(uv_tcp_t))
        uv_tcp_init(loop.uv_loop, socket);

        cdef sockaddr_in addr
        uv_ip4_addr(self.host.encode(), self.port, &addr);

        self.uv_connect = <uv_connect_t *> malloc(sizeof(uv_connect_t))

        self.uv_connect.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        uv_tcp_connect(self.uv_connect, socket, <const sockaddr*> &addr, uv_python_on_connect)

        return self


