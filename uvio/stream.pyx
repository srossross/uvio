from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdlib cimport malloc, free


from .uv cimport *

from .request cimport Request
from ._loop cimport Loop
from .handle cimport Handle

from .buffer_utils import DynamicBuffer
import inspect
import weakref
from .futures import Future

cdef void new_connection_callback(uv_stream_t* _handle, int status) with gil:
    handle = <object> _handle.data
    handle.accept(status)


cdef void alloc_callback(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) with gil:

    try:
        _buffer = <object> PyBytes_FromStringAndSize(NULL, suggested_size)
        stream = <object> handle.data
        stream._buffer = _buffer

        buf[0] = uv_buf_init(PyBytes_AsString(_buffer), suggested_size)
    except Exception as error:
        loop = <object> handle.loop.data
        loop.catch(error)



cdef void read_callback(uv_stream_t* uv_stream, ssize_t nread, const uv_buf_t* buf) with gil:


    stream = <object> uv_stream.data

    try:
        if nread == UV_EOF:
            stream.notify_end_listeners()
        elif nread >= 0:
            stream.notify_data_listeners(buf.base[:nread])
        else:
            error = IOError(nread, "Read Error: {}".format(uv_strerror(nread).decode()))
            stream.loop.catch(error)
            return


    except BaseException as error:
        stream.loop.catch(error)


cdef void write_callback(uv_write_t* _req, int status) with gil:

    if _req.data:
        req = <object> _req.data
        req.completed(status)



cdef void shutdown_callback(uv_shutdown_t* _req, int status) with gil:
    req = <object> _req.data
    req.completed(status)

class StreamShutdown(Request, Future):

    def __init__(Request self, stream):
        self.stream = stream

        uv_shutdown(
            &self.req.shutdown,
            &(<Handle> self.stream).handle.stream,
            shutdown_callback
        )

    def __uv_complete__(self, status):
        if status < 0:
            self._exception = IOError(status, "Shutdown error: {}".format(uv_strerror(status).decode()))
        self._done = True



class StreamWrite(Request, Future):

    def __init__(Request self, stream, bytes buf):

        self.stream = stream
        self.buf = buf
        self._result = len(buf)

        cdef uv_buf_t uv_buf = uv_buf_init(self.buf, len(self.buf))

        self.req.req.data = <void*> self
        failure = uv_write(
            &self.req.write,
            &(<Handle> self.stream).handle.stream,
            &uv_buf, 1,
            write_callback)


        if failure:
            msg = "Write error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

    def __uv_complete__(self, status):
        if status < 0:
            self._exception = IOError(status, "Wrire error: {}".format(uv_strerror(status).decode()))
        self._done = True

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

    def __uv_start__(self, loop):

        self._is_active = True
        self.loop = loop

        self.process()


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

        if self.should_flush:
            if self.readline:
                self._result = self.stream._read_buffer.readline(self.size)
            else:
                self._result = self.stream._read_buffer.read(self.size)
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
        return "<{} mode={} paused={} at 0x{:x} >".format(
            type(self).__qualname__,
            self.mode,
            self.paused(),
            <int> <void*> <object> self
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

    @property
    def mode(self):
        return '{}{}'.format('r' if self.readable() else '', 'w' if self.writable() else '',)


    def write(Handle self, bytes buf):

        if not self.writable():
            raise IOError("stream is not writable")

        return StreamWrite(self, buf)

    def paused(Handle self):
        return not <int> self.handle.stream.alloc_cb

    def resume(Handle self):

        if not self.readable():
            raise IOError("stream is not readable")

        if not self.paused():
            return

        self.handle.handle.data = <void*> <object> self
        self.loop.awaiting(self)

        uv_read_start(
            &self.handle.stream,
            alloc_callback,
            read_callback
        )

    def pause(Handle self):

        if self._reader:
            raise Exception("Can not pause while awaiting read")

        if self.paused():
            return

        self.loop.completed(self)

        uv_read_stop(&self.handle.stream)
        # Py_DECREF(self)

    _shutdown = None

    def shutdown(Handle self):
        if not self.writable():
            raise IOError("stream is not writable")

        if self.closing():
            raise IOError("stream is closing")

        if self._shutdown is None:
            self._shutdown = StreamShutdown(self)

        return self._shutdown

    def listen(Handle self, backlog=511):

        failure = uv_listen(&self.handle.stream, backlog, new_connection_callback)

        if failure:
            msg = "Listen error {}".format(uv_strerror(failure).decode())
            raise IOError(failure,  msg)

        self.handle.handle.data = <void*> (<object> self)
        # Don't garbage collect me
        self.loop.awaiting(self)

    def close(self):
        self.loop.completed(self)
        Handle.close(self)


    def pipe(self, stream, end=True):

        # TODO: safe await write if write buffer is full
        self.data(stream.write)

        if end:
            self.end(stream.shutdown)

        return stream

