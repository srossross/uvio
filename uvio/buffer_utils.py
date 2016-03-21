import io
import weakref
from .futures import Future


class StreamRead(Future):
    def __init__(self, stream, size):

        Future.__init__(self)

        self._stream = weakref.ref(stream)
        self.size = size
        self._result = None
        self.loop = None

        self.notify()

    def __repr__(self):
        return '<{} size={} done={}>'.format(
            type(self).__qualname__,
            self.size,
            self.done()
        )

    @property
    def stream(self):
        return self._stream()

    def start(self, loop):
        self.loop = loop

    def done(self):
        if self.stream._eof:
            return True
        else:
            return len(self.stream._read_buffer) >= self.size

    def read_result(self):
        self._result = self.stream._read_buffer[:self.size]
        self.stream._read_buffer = self.stream._read_buffer[self.size:]

    def notify(self):

        if self.done():
            self.stream.pause()

            if self._result is None:
                self.read_result()


            if self.loop:
                self.loop.completed(self)
        else:
            self.stream.resume()



class StreamReadline(StreamRead):
    def __init__(self, stream, size, line_end=b'\n'):
        self.line_end = line_end

        super().__init__(stream, size)

    def __repr__(self):
        return '<{} end={} size={} done={}>'.format(
            type(self).__qualname__,
            self.line_end,
            self.size,
            self.done()
        )

    def done(self):
        if self._result is not None:
            return True
        elif self.stream._eof:
            return True
        elif self.line_end in self.stream._read_buffer:
            return True
        elif self.size and len(self.stream._read_buffer) >= self.size:
            return True

        return False


    def read_result(self):

        buf = self.stream._read_buffer

        try:
            index = buf.index(self.line_end) + len(self.line_end)
        except ValueError:
            index = self.size if self.size else len(buf)

        if self.size:
            index = min(index, self.size)

        self._result = self.stream._read_buffer[:index]
        self.stream._read_buffer = self.stream._read_buffer[index:]



