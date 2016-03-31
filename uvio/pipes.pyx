from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdlib cimport malloc, free


from .uv cimport *

from .request cimport Request
from ._loop cimport Loop
from .handle cimport Handle

import io
import inspect
import weakref
from .futures import Future
from .stream import Stream
from .loop import get_current_loop

cdef extern from *:
    void PyEval_InitThreads()


cdef void connect_callback(uv_connect_t * _req, int status) with gil:

    req = <object> _req.data
    req.completed(status)


async def listen(handler, name, backlog=511):
    '''listen(handler, name, backlog=511)

    example::

        async def echo_handler(socket):

            @socket.data
            def echo(buf):
                print("server: on data", buf)
                socket.write(b"echo: " + buf)
                socket.close()

            @socket.end
            def end():
                print("on socket end")

        server = await uvio.pipes.listen(echo_handler, "test.sock")
    '''
    PyEval_InitThreads()

    loop = await get_current_loop()

    server = Pipe(loop, handler)
    server.bind(name)
    server.listen(backlog)

    return server


class connect(Request, Future):
    '''connect(name, ipc=False)

    Connect to a named pipe (windows) or a unix domain socket

    example::

        pipe = await uvio.pipes.connect("test.sock")

        @pipe.data
        def on_data(buf):
            print("pipe recieved some data!", buf)

        await pipe.write(b'Write to the pipe!')

    '''
    def __init__(self, name, ipc=False):
        self.name = name
        self.ipc = ipc

    def __uv_init__(Request self, loop):

        PyEval_InitThreads()

        self._result = Pipe(loop, self.ipc)

        failure = uv_pipe_connect(
            &self.req.connect,
            &(<Handle> self._result).handle.pipe,
            self.name.encode(),
            connect_callback
        )
        if failure:
            msg = "Error connecting pipe '{}': {}".format(
                self.name,
                uv_strerror(failure).decode()
            )
            raise IOError(failure,  msg)

    def before_send(self):
        if not self._exception:
            self._result.resume()

    def __uv_complete__(self, status):

        if status < 0:
            self._exception = IOError(status, "Connect Error: {}".format(uv_strerror(status).decode()))
            return

        self._done = True

class Pipe(Stream):

    def __init__(Handle self, Loop loop=None, handler=None, ipc=False):
        Stream.__init__(self)
        self.ipc = ipc
        self._handler = handler
        if loop is not None:
            self.__uv_init__(loop)

    def __uv_init__(Handle self, Loop loop):
        uv_pipe_init(loop.uv_loop, &self.handle.pipe, self.ipc)

    def bind(Handle self, name):
        "Bind the pipe to a file path (Unix) or a name (Windows)."

        failure = uv_pipe_bind(&self.handle.pipe, name.encode())
        if failure:
            msg = "Error binding pipe '{}': {}".format(name, uv_strerror(failure).decode())
            raise IOError(failure,  msg)

    def get_client(Handle self):
        return Pipe(self.loop)

    def getsockname(Handle self):
        cdef size_t size = 1024
        _buffer = <object> PyBytes_FromStringAndSize(NULL, size)

        uv_pipe_getsockname(&self.handle.pipe, _buffer, &size);
        if not size:
            return b''

        return _buffer[:size-1].decode()


    # def peername(Handle self):
    #     cdef size_t size = 1024
    #     _buffer = <object> PyBytes_FromStringAndSize(NULL, size)

    #     uv_pipe_getpeername(&self.handle.pipe, _buffer, &size);

    #     return _buffer[:size]

    def __repr__(Handle self):
        return "<{} {} mode='{}' paused={} at 0x{:x} >".format(
            type(self).__qualname__,
            self.sockname(),
            self.mode or '-',
            self.paused(),
            <int> <void*> <object> self
        )
