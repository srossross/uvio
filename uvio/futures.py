
class Future:
    _coro = None
    _done = False
    _result = None
    _exec_info = (None, None, None)

    def result(self):
        return self._result

    def done(self):
        return self._done

    def __await__(self):

        if not self._done:
            yield self
        return self.result()


    def start(self, loop, coro=None):

        if coro and self._coro:
            raise Exception("coroutine continuuation already set")
        elif coro:
            self._coro = coro

        if self.is_active():
            return self

        self._uv_start(loop)

        return self



    def set_completed(self, error=None):
        print("set_completed", error)

        if error:
            self._exec_info[1] = error

        self._done  = True
        if self._coro is None:
            return

        try:
            if self._exec_info[1]:
                value = self._coro.throw(*self._exec_info)
            else:
                value = self._coro.send(self.result())
        except StopIteration:
            return

        if isinstance(value, Future):
            value.start(self.loop, self._coro)
        else:
            raise Exception("expected value to be a future (got: {})".format(value))

