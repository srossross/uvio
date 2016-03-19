import inspect
import sys

from functools import partial
from ._loop import Loop as _Loop
from .idle import Idle
from .timer import Timer
from .futures import Future

def process_until_await(loop, coro, args, exception):


    while 1:
        try:
            if exception:
                future = coro.throw(exception)
            else:
                future = coro.send(None)

        except StopIteration:
            return
        except BaseException as err:
            loop.catch(err)
            return

        future.ensure_started(loop)

        exception = future.exception()

        if future.done():
            continue
        else:
            loop.awaiting(future, coro)
            return


class Loop(_Loop):

    def __init__(self, name='?'):
        self.name = name
        self._exceptions = []
        self.exception_handler = None
        self.ready = set()
        self._awaiting = {}

    def next_tick(self, callback, *args, **kwargs):
        if inspect.iscoroutinefunction(callback):
            raise Exception("Did you mean ot create a coroutine (got: {})".format(callback))

        if not inspect.iscoroutine(callback):
            callback = partial(callback, *args, **kwargs)

        self.ready.add((callback, None, None))

    def set_timeout(self, callback, timeout):
        timer = Timer(callback, timeout)
        timer.start(self)
        self._awaiting.setdefault(timer, [])
        return timer

    def __repr__(self):
        return "<{} name='{}' alive={}>".format(
            type(self).__qualname__,
            self.name,
            self.alive()
        )


    @property
    def exceptions(self):
        return self._exceptions

    def catch(self, err):
        etype, evalue, traceback = sys.exc_info()
        if evalue is None:
            evalue = err

        self._exceptions.append((etype, evalue, traceback))

    def __enter__(self):
        self.run()
        return self

    def __exit__(self, *args):
        self.close()
        return

    def awaiting(self, future, *coroutines):
        self._awaiting.setdefault(future, []).extend(coroutines)


    def completed(self, future):

        coroutines = self._awaiting.pop(future, [])
        self.ready.update((coroutine, None, future.exception()) for coroutine in coroutines)

        if self.ready:
            self.ref_ticker()



    def tick(self):

        self.handle_exceptions()

        if not self.ready:
            # Don't let idle block the loop from exiting
            # There should be other handdles blocking exiting if
            # there is nothing ready
            self.unref_ticker()
            return

        coroutine_or_func, args, exception = self.ready.pop()

        if inspect.iscoroutine(coroutine_or_func):
            process_until_await(self, coroutine_or_func, args, exception)
        else:
            coroutine_or_func()



    def handle_exceptions(self):

        while self.exceptions:
            if self.exception_handler is None:
                return self.stop()

            try:
                self.exception_handler(*self.exceptions[0])
            except BaseException:
                return self.stop()
            else:
                self.exceptions.pop(0)



class get_current_loop:
    _done = False

    def exception(self):
        pass
    def done(self):
        return self._done

    def ensure_started(self, loop):
        self.loop = loop

    def __await__(self):
        self._done = True
        yield self
        return self.loop
