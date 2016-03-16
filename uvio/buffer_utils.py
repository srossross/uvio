import io


class DynamicBuffer:

    def __init__(self):
        self._eof = False
        self._buffer = None

    def append(self, buf):
        if not self._buffer:
            self._buffer = buf
        else:
            self._buffer += buf

    def eof(self):
        self._eof = True

    def __len__(self):
        return len(self._buffer)

    def read(self, size):
        result = self._buffer[:size]
        self._buffer = self._buffer[size:]
        return result
