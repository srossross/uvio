from .buffer_utils import StreamRead, StreamReadline

class StreamWrapper:
    """
    Stream handles provide an abstraction of a duplex communication channel.

    The :class:`Stream` is an abstract type,
    uvio provides stream implementations for uvio.net and uvio.pipes

    """

    def __init__(self, stream):
        self.stream = stream



    def data(self, coro_func):
        '''data(coro_func)

        Register a data callback for asyncronous data collection.

        :param coro_func:

        eg::

            stream.data(collect_data)

        or eg::

            @stream.data
            def collect_data(buf):
                result = do_somthing(buf)

        '''
        return self.stream.data(coro_func)

    def end(self, coro_func):
        '''end(coro_func)

        Register a data callback for when the end of the stream is reached

        '''
        return self.stream.data(coro_func)

    def readable(self):
        '''readable()
        Test if stream is readable'''
        return self.stream.readable()

    def writable(self):
        '''writable()
        Test if stream is writable
        '''
        return self.stream.writable()

    @property
    def mode(self):
        'mode of the stream (same as python file objects)'
        return stream.mode


    def write(self,buf):
        '''write(buf)

        write to the stream. It is optional to await for the write to succeed.
        '''
        return self.stream.write(buf)

    def paused(self):
        '''paused()

        Test if the stream is paused.
        '''
        return self.stream.paused()

    def resume(self):
        '''resume()
        Un-pause the stream. resume the data and end callback functions.

        when the stream is resumed the registered stream.data callback functions will be called
        asyncronously until the eof is reached or the stream is paused.
        '''
        self.stream.resume()

    def pause(self):
        '''pause()

        pause the stream
        '''
        self.stream.pause()


    def shutdown(Handle self):
        '''shutdown()

        Shutdown the outgoing (write) side of a duplex stream.
        It waits for pending write requests to complete.

        This method is awaitable.
        '''


        return self.stream.shutdown()


    def close(self):
        '''close()
        close the stream
        '''
        self.stream.close()


    def pipe(self, other, end=True):

        # TODO: safe await write if write buffer is full
        self.stream.pipe(other, end)


    def __rshift__(self, other):
        self.stream.pipe(other)


class BufferedStreamIO(StreamWrapper):
    """
    Stream handles provide an abstraction of a duplex communication channel.

    The :class:`Stream` is an abstract type,
    uvio provides stream implementations for uvio.net and uvio.pipes

    """

    def __init__(self, stream):
        self._paused = False
        self._read_buffer = b''
        self._eof = False
        self._readers = []
        self.stream = stream



    def unshift(self, buf):
        '''unshift(buf)
        Not implemented:
        unshift a buffer
        '''
        raise NotImplementedError("this stream is not buffering input")


        self._read_buffer = buf + self._read_buffer

    def read(self, n):
        '''read(n)
        read at most n bytes from the stream
        '''

        reader = StreamRead(self, n)

        if not reader.done():
            self._readers.append(reader)

        return reader


    def readline(self, max_size=None, end=b'\n'):
        '''readline(max_size=None, end=b'\\n')
        read and return bytes until `end` is encountered
        '''


        reader = StreamReadline(self, max_size, end)

        if not reader.done():
            self._readers.append(reader)

        return reader
