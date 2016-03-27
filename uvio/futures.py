
class Future:
    _done = False
    _result = None
    _started = False

    _exception = None

    def exception(self):
        return self._exception

    def result(self):
        return self._result

    def done(self):
        return self._done

    def before_send(self):
        pass


    def ensure_started(self, loop):

        if self._started:
            return

        self._started = True
        loop.awaiting(self)
        self.start(loop)

    def completed(self, *args):

        self.loop.completed(self)

        try:
            self.__uv_complete__(*args)
        except BaseException as err:
            self.loop.catch(err)

    def __uv_complete__(self):
        return None

    def __await__(self):
        self._awaiting = True
        yield self
        self._awaiting = False
        return self.result()


