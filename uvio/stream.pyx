from cpython.bytes cimport PyBytes_FromStringAndSize
from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .request cimport Request
from .loop cimport Loop
from .handle cimport Handle

from .futures import Future

cdef void uv_python_alloc_cb(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf):

    print("uv_python_alloc_cb: uv_handle.data", <int> handle.data)

    buf[0] = uv_buf_init(NULL, 0)

cdef void uv_python_read_cb(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf):
    pass

cdef void uv_py_write_cb(uv_write_t* req, int status) with gil:

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


class StreamWrite(Request, Future):

    def __init__(self, stream, bytes buf):
        self.stream = stream
        self.buf = buf
        self._result = len(buf)

    def is_active(Request self):
        return <int> self.req

    def _uv_start(Request self, Loop loop):

        self.req = <uv_req_t *> malloc(sizeof(uv_write_t));

        cdef uv_buf_t buf = uv_buf_init(self.buf, len(self.buf))

        failure = uv_write(
            <uv_write_t*> self.req,
            <uv_stream_t*> (<Handle> self.stream).uv_handle,
            &buf, 1,
            uv_py_write_cb)

        if failure:
            msg = "Write error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

        self.req.data = <void*> (<PyObject*> self)
        Py_INCREF(self)


class UVStream(Handle):

    def __init__(self):
        self._paused = False

    def data(self, coro_func):
        self._data = coro_func

    def end(self, coro_func):
        self._end = coro_func

    def readable(Handle self):
        return bool(uv_is_readable(<uv_stream_t*> self.uv_handle))

    def writable(Handle self):
        return bool(uv_is_writable(<uv_stream_t*> self.uv_handle))

    def write(Handle self, bytes buf):
        return StreamWrite(self, buf)

    def resume(Handle self):

        self.uv_handle.data = <void*> <object> self
        # Py_INCREF(self)

        print("Stream.resume: self.uv_handle.data", <int> self.uv_handle.data)

        uv_read_start(
            <uv_stream_t*> self.uv_handle,
            uv_python_alloc_cb,
            uv_python_read_cb
        )

    def pause(Handle self):
        uv_read_stop(<uv_stream_t*> self.uv_handle)
        # Py_DECREF(self)


