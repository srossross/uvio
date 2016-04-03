
class StreamWrapper:

    def __init__(self, stream):
        self._stream = stream

    @property
    def stream(self):
        return self._stream




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
        if not self.readable():
            raise IOError("stream is not readable")

        self._data_listeners.append(coro_func)
        return coro_func

    def notify_data_listeners(self, buf):
        if self.buffering:
            self._read_buffer += buf

            while self._readers:
                if self._readers[0].done():
                    reader = self._readers.pop(0)
                    reader.notify()


        for listener in self._data_listeners:
            result = listener(buf)
            if inspect.iscoroutine(result):
                self.loop.next_tick(result)

    def end(self, coro_func):
        '''end(coro_func)

        Register a data callback for when the end of the stream is reached

        '''

        if not self.readable():
            raise IOError("stream is not readable")

        self._end_listeners.append(coro_func)
        return coro_func

    def notify_end_listeners(self):

        self._eof = True

        while self._readers:
            if self._readers[0].done():
                reader = self._readers.pop(0)
                reader.notify()


        for listener in self._end_listeners:
            result = listener()

            if inspect.iscoroutine(result):
                self.loop.next_tick(result)



    def readable(Handle self):
        '''readable()
        Test if stream is readable'''
        return bool(uv_is_readable(&self.handle.stream))

    def writable(Handle self):
        '''writable()
        Test if stream is writable
        '''
        return bool(uv_is_writable(&self.handle.stream))

    @property
    def mode(self):
        'mode of the stream (same as python file objects)'
        return '{}{}'.format('r' if self.readable() else '', 'w' if self.writable() else '',)


    def write(Handle self, bytes buf):
        '''write(buf)

        write to the stream. It is optional to await for the write to succeed.
        '''
        if not self.writable():
            raise IOError("stream is not writable")

        return StreamWrite(self, buf)

    def paused(Handle self):
        '''paused()

        Test if the stream is paused.
        '''
        return not <int> self.handle.stream.alloc_cb

    def resume(Handle self):
        '''resume()
        Un-pause the stream. resume the data and end callback functions.

        when the stream is resumed the registered stream.data callback functions will be called
        asyncronously until the eof is reached or the stream is paused.
        '''
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
        '''pause()

        pause the stream
        '''
        if self.paused():
            return

        # Take this off the _awaiting set to
        # allow refcount to go to 0
        self.loop.completed(self)
        uv_read_stop(&self.handle.stream)

    _shutdown = None

    def shutdown(self):
        '''shutdown()

        Shutdown the outgoing (write) side of a duplex stream.
        It waits for pending write requests to complete.

        This method is awaitable.



        '''
        self.stream.shutdown()
        if not self.writable():
            raise IOError("stream is not writable")

        if self.closing():
            raise IOError("stream is closing")

        return StreamShutdown(self)

        return self._shutdown


    def close(self):
        '''close()
        close the stream
        '''
        self.stream.close()

    def pipe(self, stream, end=True):
        self.stream.pipe(stream, end)

    def __rshift__(self, other):
        return self.stream.pipe(other)
