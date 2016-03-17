from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *

from .request cimport Request
from .loop cimport Loop, listen_callback
from .handle cimport Handle

import io
import inspect
import weakref
from .futures import Future
from .stream import Stream
from .loop import get_current_loop

cdef extern from *:
    void PyEval_InitThreads()

cdef void new_connection_callback(uv_stream_t* handle, int status) with gil:
    loop = <object> handle.loop.data
    stream = <object> handle.data
    loop.new_connection_callback(stream, status)

cdef void uv_python_pipe_connect_cb(uv_connect_t *req, int status) with gil:
    pipe_connect = <object> req.data


    if status < 0:
        error = IOError(status, "Connect Error: {}".format(uv_strerror(status).decode()))
    else:
        error = None
    try:

        pipe_connect.set_completed(error)
    except Exception as error:
        loop = <object> req.handle.loop.data
        loop.catch(error)

    Py_DECREF(pipe_connect)
    req.data = NULL

async def listen(handler, name, backlog=511):

    PyEval_InitThreads()

    loop = await get_current_loop()

    server = Pipe(loop, handler)
    server.bind(name)
    server.listen(backlog)
    return server


class connect(Request, Future):

    def __init__(self, name, ipc=False):
        self.name = name
        self.ipc = ipc

    @property
    def loop(self):
        return self._loop

    def __uv_start__(Request self, loop):

        self._loop = loop

        PyEval_InitThreads()

        self._result = Pipe(loop, self.ipc)

        failure = uv_pipe_connect(
            &self.req.connect,
            &(<Handle> self._result).handle.pipe,
            self.name.encode(),
            uv_python_pipe_connect_cb
        )
        if failure:
            msg = "Error connecting pipe '{}': {}".format(
                self.name,
                uv_strerror(failure).decode()
            )
            raise IOError(failure,  msg)

        self.req.req.data = <void*> <object> self
        Py_INCREF(self)

    def set_completed(self, err):

        if not err:
            self._result.resume()

        Future.set_completed(self, err)

class Pipe(Stream):

    def __init__(Handle self, Loop loop, handler=None, ipc=False):
        Stream.__init__(self)
        self.ipc = ipc
        self._handler = handler
        uv_pipe_init(loop.uv_loop, &self.handle.pipe, ipc)

    def bind(Handle self, name):
        "Bind the pipe to a file path (Unix) or a name (Windows)."

        failure = uv_pipe_bind(&self.handle.pipe, name.encode())
        if failure:
            msg = "Error binding pipe '{}': {}".format(name, uv_strerror(failure).decode())
            raise IOError(failure,  msg)

    def get_client(Handle self):
        return Pipe(self.loop)

    def accept(Handle self):

        cdef Handle client = self.get_client()

        failure = uv_accept(&self.handle.stream, &client.handle.stream)

        if failure:
            client.close()
            msg = "Accept error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)
        else:
            coro = self._handler(client)

            try:
                client.resume()
                coro.send(None)
            except StopIteration:
                pass
            else:

                self.loop.next_tick(coro)


    def sockname(Handle self):
        cdef size_t size = 1024
        _buffer = <object> PyBytes_FromStringAndSize(NULL, size)

        uv_pipe_getsockname(&self.handle.pipe, _buffer, &size);

        return _buffer[:size-1].decode()

    # def peername(Handle self):
    #     cdef size_t size = 1024
    #     _buffer = <object> PyBytes_FromStringAndSize(NULL, size)

    #     uv_pipe_getpeername(&self.handle.pipe, _buffer, &size);

    #     return _buffer[:size]






