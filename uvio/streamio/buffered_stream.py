
from .stream_wrapper import StreamWrapper
from .buffer_utils import StreamRead, StreamReadline

class BufferedStream(StreamWrapper):

    def __init__(self, stream):

        super().__init__(stream)

        self.buffering = False
        self._read_buffer = b''
        self._eof = False
        self._readers = []

        self.stream.data(self._notify_reader_data)
        self.stream.end(self._notify_reader_end)

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
        self.buffering = True

        reader = StreamRead(self, n)

        if not reader.done():
            self._readers.append(reader)

        return reader


    def readline(self, max_size=None, end=b'\n'):
        '''readline(max_size=None, end=b'\\n')
        read and return bytes until `end` is encountered
        '''
        self.buffering = True

        reader = StreamReadline(self, max_size, end)

        if not reader.done():
            self._readers.append(reader)

        return reader


    def _notify_reader_data(self, buf):
        if self.buffering:
            self._read_buffer += buf

            while self._readers:
                if self._readers[0].done():
                    reader = self._readers.pop(0)
                    reader.notify()


    def _notify_reader_end(self):

        self._eof = True

        while self._readers:
            if self._readers[0].done():
                reader = self._readers.pop(0)
                reader.notify()

