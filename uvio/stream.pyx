from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *

from .request cimport Request
from .loop cimport Loop
from .handle cimport Handle

import inspect
from .futures import Future

cdef void uv_python_alloc_cb(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) with gil:

    try:
        _buffer = <object> PyBytes_FromStringAndSize(NULL, suggested_size)
        stream = <object> handle.data
        stream._buffer = _buffer
        _buffer

        buf[0] = uv_buf_init(PyBytes_AsString(_buffer), suggested_size)
    except Exception as error:
        loop = <object> handle.loop.data
        loop.catch(error)



cdef void uv_python_read_cb(uv_stream_t* uv_stream, ssize_t nread, const uv_buf_t* buf) with gil:

    stream = <object> uv_stream.data

    loop = <object> uv_stream.loop.data


    try:
        if nread == UV_EOF:
            if not stream._end:
                return

            if inspect.iscoroutinefunction(stream._end):
                loop.next_tick(stream._end())
            else:
                stream._end()

        elif nread >= 0:

            if not stream._data:
                error = RuntimeError("stream is started and no data callback is defined")
                loop.catch(error)
                return

            if inspect.iscoroutinefunction(stream._data):
                loop.next_tick(stream._data(buf.base[:nread]))
            else:
                stream._data(buf.base[:nread])
        else:
            error = IOError(nread, "Read Error: {}".format(uv_strerror(nread).decode()))
            loop.catch(error)
            return


    except Exception as error:
        loop.catch(error)


cdef void uv_py_write_cb(uv_write_t* req, int status) with gil:
    print("uv_py_write_cb")

    if status < 0:
        network_error = IOError(status, "Write error: {}".format(uv_strerror(status).decode()))
    else:
        network_error = None

    stream = <object> req.data

    try:
        stream.set_completed(network_error)
    except BaseException as err:

        loop = <object> req.handle.loop.data
        loop.catch(err)

    Py_DECREF(stream)


cdef void uv_python_shutdown_cb(uv_shutdown_t* req, int status) with gil:

    if status < 0:
        network_error = IOError(status, "Shutdown error: {}".format(uv_strerror(status).decode()))
    else:
        network_error = None

    shutdown = <object> req.data

    try:
        shutdown.set_completed(network_error)
    except BaseException as err:

        loop = <object> req.handle.loop.data
        loop.catch(err)

    Py_DECREF(shutdown)

class StreamShutdown(Request, Future):

    def __init__(self, stream):
        self.stream = stream

    @property
    def loop(Request self):
        return <object> self.req.write.handle.loop.data

    def _uv_start(Request self, Loop loop):

        uv_shutdown(
            &self.req.shutdown,
            &(<Handle> self.stream).handle.stream,
            uv_python_shutdown_cb
        )

        self.req.req.data = <void*> (<PyObject*> self)
        Py_INCREF(self)


class StreamWrite(Request, Future):

    def __init__(self, stream, bytes buf):
        self.stream = stream
        self.buf = buf
        self._result = len(buf)

    @property
    def loop(Request self):
        return <object> self.req.write.handle.loop.data

    def _uv_start(Request self, Loop loop):

        cdef uv_buf_t buf = uv_buf_init(self.buf, len(self.buf))

        failure = uv_write(
            &self.req.write,
            &(<Handle> self.stream).handle.stream,
            &buf, 1,
            uv_py_write_cb)

        if failure:
            msg = "Write error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

        self.req.req.data = <void*> (<PyObject*> self)
        Py_INCREF(self)


class Stream(Handle):

    def __init__(self):
        self._paused = False
        self._data = None
        self._end = None

    def data(self, coro_func):
        self.resume()
        self._data = coro_func
        return coro_func

    def end(self, coro_func):
        self.resume()
        self._end = coro_func
        return coro_func

    def readable(Handle self):
        return bool(uv_is_readable(&self.handle.stream))

    def writable(Handle self):
        return bool(uv_is_writable(&self.handle.stream))

    def write(Handle self, bytes buf):
        return StreamWrite(self, buf).start(self.loop)

    def paused(Handle self):
        return not <int> self.handle.stream.alloc_cb

    def resume(Handle self):

        if not self.paused():
            return

        self.handle.handle.data = <void*> <object> self

        # TODO: when to decref???
        Py_INCREF(self)

        uv_read_start(
            &self.handle.stream,
            uv_python_alloc_cb,
            uv_python_read_cb
        )

    def pause(Handle self):

        if self.paused():
            return
        self.handle.handle.data = NULL
        uv_read_stop(&self.handle.stream)
        # Py_DECREF(self)


    def shutdown(Handle self):
        return StreamShutdown(self).start(self.loop)


class Pipe(Stream, Future):

    def __init__(self, ipc=False):
        self.ipc = ipc

    def _uv_start(Handle self, Loop loop):
        uv_pipe_init(loop.uv_loop, &self.handle.pipe, self.ipc)




