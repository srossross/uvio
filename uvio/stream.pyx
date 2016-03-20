from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdlib cimport malloc, free


from .uv cimport *

from .request cimport Request
from ._loop cimport Loop
from .handle cimport Handle

from .buffer_utils import StreamRead, StreamReadline
import inspect
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

    if _req.data:
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



class Stream(Handle):

    def __init__(self):
        self._paused = False
        self._data_listeners = []
        self._end_listeners = []
        self._buffering = False
        self._read_buffer = b''
        self._eof = False
        self._reader = None

    @property
    def buffering(self):
        return self._buffering

    @buffering.setter
    def buffering(self, value):
        self._buffering = bool(value)


    def __repr__(Handle self):
        return "<{} mode='{}' paused={} at 0x{:x} >".format(
            type(self).__qualname__,
            self.mode or '-',
            self.paused(),
            <int> <void*> <object> self
        )

    def unshift(self, buf):
        if not self.buffering:
            raise Exception("this stream is not buffering input")


        self._read_buffer = buf + self._read_buffer

    def read(self, n):
        self.buffering = True
        if self._reader is not None:
            raise Exception("already reading")

        self._reader = StreamRead(self, n)
        return self._reader


    def readline(self, max_size=None):
        return StreamReadline(self, max_size)

    def data(self, coro_func):

        if not self.readable():
            raise IOError("stream is not readable")

        self._data_listeners.append(coro_func)
        return coro_func

    def notify_data_listeners(self, buf):
        if self.buffering:
            self._read_buffer += buf

            if self._reader:
                self._reader.notify()

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
            self._reader.notify()

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
        if self.paused():
            return

        # Take this off the _awaiting set to
        # allow refcount to go to 0
        self.loop.completed(self)
        uv_read_stop(&self.handle.stream)

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

    def accept(Handle self, status):
        print("-- Accept --")
        print("accept", self, status)
        print("-- Accept --")

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


    def close(self):
        self.loop.completed(self)
        Handle.close(self)


    def pipe(self, stream, end=True):

        # TODO: safe await write if write buffer is full
        self.data(stream.write)

        if end:
            self.end(stream.shutdown)

        return stream

