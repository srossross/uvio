from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *

from .request cimport Request
from .loop cimport Loop, listen_callback
from .handle cimport Handle

from .buffer_utils import DynamicBuffer
import inspect
import weakref
from .futures import Future

cdef void new_connection_callback(uv_stream_t* handle, int status) with gil:
    loop = <object> handle.loop.data
    stream = <object> handle.data
    loop.new_connection_callback(stream, status)


cdef void uv_python_alloc_cb(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) with gil:

    try:
        _buffer = <object> PyBytes_FromStringAndSize(NULL, suggested_size)
        stream = <object> handle.data
        stream._buffer = _buffer

        buf[0] = uv_buf_init(PyBytes_AsString(_buffer), suggested_size)
    except Exception as error:
        loop = <object> handle.loop.data
        loop.catch(error)



cdef void uv_python_read_cb(uv_stream_t* uv_stream, ssize_t nread, const uv_buf_t* buf) with gil:


    stream = <object> uv_stream.data

    loop = <object> uv_stream.loop.data


    try:
        if nread == UV_EOF:
            stream.notify_end_listeners()
        elif nread >= 0:
            stream.notify_data_listeners(buf.base[:nread])
        else:
            error = IOError(nread, "Read Error: {}".format(uv_strerror(nread).decode()))
            loop.catch(error)
            return


    except Exception as error:
        loop.catch(error)


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

class BufferedStreamReader(Future):
    def __init__(self, stream, size, readline=False):
        self._stream = weakref.ref(stream)
        self.size = size
        self.readline = readline
        self._out_buffers = []
        self._is_active = False
        Future.__init__(self)

    @property
    def stream(self):
        return self._stream()

    def is_active(self):
        return self._is_active

    def _uv_start(self, loop):
        print("uv_start", loop)
        self._is_active = True
        self.loop = loop

        self.process()
        print("self._result", self._result)

    def result(self):
        return self._result

    @property
    def should_flush(self):
        if self.stream._eof:
            return True
        else:
            should_flush = len(self.stream._read_buffer) >= self.size
            if self.readline:
                should_flush |= '\n' in self.stream._read_buffer

            return should_flush

    def process(self):
        print("process")
        print("self.should_flush", self.should_flush)
        print("self.should_flush buffer", self.stream._read_buffer._buffer)

        if self.should_flush:
            if self.readline:
                self._result = self.stream._read_buffer.readline(self.size)
            else:
                self._result = self.stream._read_buffer.read(self.size)
            print("set_completed", self._result)
            self.stream._reader = None
            self.set_completed()



class Stream(Handle):

    def __init__(self):
        self._paused = False
        self._data_listeners = []
        self._end_listeners = []
        self._read_buffer = DynamicBuffer()
        self._eof = False
        self._reader = None

    def __repr__(Handle self):
        return "<{} readable={} writable={} paused={} at 0x{:x} >".format(
            type(self).__qualname__,

            self.readable(),
            self.writable(),
            self.paused(),
            <int> <PyObject*> <object> self
        )

    def unshift(self, buf):
        self._read_buffer.unshift(buf)

    def read(self, n):
        if self._reader is None:
            self._reader = BufferedStreamReader(self, n)
            return self._reader

        raise Exception("already reading")


    def readline(self, size=None):
        return BufferedStreamReader(self, size, readline=True)

    def data(self, coro_func):

        if not self.readable():
            raise IOError("stream is not readable")

        self._data_listeners.append(coro_func)
        return coro_func

    def notify_data_listeners(self, buf):
        if self._reader:
            self._read_buffer.append(buf)
            self._reader.process()

        for listener in self._data_listeners:
            listener(buf)

    def end(self, coro_func):

        if not self.readable():
            raise IOError("stream is not readable")

        self._end_listeners.append(coro_func)
        return coro_func

    def notify_end_listeners(self):

        self._eof = True

        if self._reader:
            self._read_buffer.eof()
            self._reader.process()

        for listener in self._end_listeners:
            listener()


    def readable(Handle self):
        return bool(uv_is_readable(&self.handle.stream))

    def writable(Handle self):
        return bool(uv_is_writable(&self.handle.stream))

    def write(Handle self, bytes buf):

        if not self.writable():
            raise IOError("stream is not writable")

        return StreamWrite(self, buf).start(self.loop)

    def paused(Handle self):
        return not <int> self.handle.stream.alloc_cb

    def resume(Handle self):

        if not self.readable():
            raise IOError("stream is not readable")

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

        if self._reader:
            raise Exception("Can not pause while awaiting read")

        if self.paused():
            return
        self.handle.handle.data = NULL
        uv_read_stop(&self.handle.stream)
        # Py_DECREF(self)

    _shutdown = None

    def shutdown(Handle self):
        if not self.writable():
            raise IOError("stream is not writable")

        if self.closing():
            raise IOError("stream is closing")

        if self._shutdown is None:
            self._shutdown = StreamShutdown(self).start(self.loop)

        return self._shutdown

    def listen(Handle self, backlog=511):

        failure = uv_listen(&self.handle.stream, backlog, new_connection_callback)

        if failure:
            msg = "Listen error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

        self.handle.handle.data = <void*> (<PyObject*> self)
        # Don't garbage collect me
        self.loop._add_handle(self)


    def pipe(self, stream, end=True):

        # TODO: safe await write if write buffer is full
        self.data(stream.write)

        if end:
            self.end(stream.shutdown)

        return stream

