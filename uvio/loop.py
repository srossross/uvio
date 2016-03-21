"""
UVIO Event Loop

"""
import inspect
import sys

from functools import partial
from ._loop import Loop as _Loop
from .idle import Idle
from .timer import Timer
from .futures import Future

def process_until_await(loop, future, coro):
    """
    Process the coroutine `coro` until it is completed

    :param loop: an uvio.loop.Loop instance
    :param future: an uvio.futures.Future instance
    :param coro: a coroutine
    """

    while 1:

        try:
            if future and future.exception():
                future = coro.throw(future.exception())
            else:

                if future:
                    future.before_send()

                future = coro.send(None)

        except StopIteration:
            return
        except BaseException as err:
            loop.catch(err)
            return

        future.ensure_started(loop)

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
        self.ready = {}
        self._awaiting = {}

    def next_tick(self, callback, *args, **kwargs):
        """
        Once the current event loop turn runs to completion,
        call the callback or coroutine function::

            loop.next_tick(callback)


        """
        if inspect.iscoroutinefunction(callback):
            raise Exception("Did you mean ot create a coroutine (got: {})".format(callback))

        if not inspect.iscoroutine(callback):
            callback = partial(callback, *args, **kwargs)

        self.ready[callback] = None

    def set_timeout(self, callback, timeout):
        """

        call the callback after `timeout` seconds
        """
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
        'exceptions'
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

        self.ready.update({coroutine: future for coroutine in coroutines})

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
        coroutine_or_func, future = self.ready.popitem()

        if inspect.iscoroutine(coroutine_or_func):
            process_until_await(self, future, coroutine_or_func)
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
    """get_current_loop()

    This awaitable coroutine returns the loop that is currently processing the
    outer async function::

        loop = await get_current_loop()

    """
    _done = False

    def exception(self):
        pass

    def done(self):
        return self._done

    def ensure_started(self, loop):
        self.loop = loop

    def before_send(self):
        pass

    def __await__(self):
        self._done = True
        yield self
        return self.loop
