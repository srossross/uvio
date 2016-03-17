
class Future:
    _coroutine = None
    _done = False
    _result = None

    @property
    def coro(self):
        return self._coroutine

    @coro.setter
    def coro(self, value):
        self._coroutine = value

    @coro.deleter
    def coro(self):
        self._coroutine = None



    def result(self):
        return self._result

    def done(self):
        return self._done

    def start(self):
        self.__uv_start__()

    def __uv_start__(self):
        pass

    def __uv_complete__(self):
        return None

    def __await__(self):

        if self.done():
            raise Exception("future has already be awaited")

        self.loop.active_handles.add(self)

        self.__uv_start__()
        print("__iter__.started")
        args = yield self
        print("__iter__: yielded args", args)
        result = self.__uv_complete__(*args)

        self._done = True

        del self.coro
        print("__iter__: returns", result)

        return result


