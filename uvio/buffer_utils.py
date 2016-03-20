import io
import weakref
from .futures import Future


class StreamRead(Future):
    def __init__(self, stream, size):

        Future.__init__(self)

        self._stream = weakref.ref(stream)
        self.size = size
        self._result = None

        if not self.ready:
            stream.resume()

    @property
    def stream(self):
        return self._stream()

    def start(self, loop):
        self.loop = loop

    @property
    def ready(self):
        if self.stream._eof:
            return True
        else:
            return len(self.stream._read_buffer) >= self.size


    def notify(self):
        print("notify", self)
        print("self.ready", self.ready)
        print('self.stream._read_buffer', self.stream._read_buffer, self.size)

        if self.ready:
            if self._result is None:
                # self.stream._reader = None
                self._result = self.stream._read_buffer[:self.size]
                self.stream._read_buffer = self.stream._read_buffer[self.size:]

            self.stream.pause()
            print('self.loop.completed', self)
            self.loop.completed(self)

            self.stream._reader = None




class StreamReadline:
    pass
