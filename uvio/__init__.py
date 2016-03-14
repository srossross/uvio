from functools import wraps, partial
from inspect import iscoroutine
from .loop import Loop
from .timer import Timer
from .idle import Idle
from .workers import worker
from . import fs

get_default_loop = Loop.get_default_loop


def run(*func, timeout=None):
    if not func:
        return partial(run, timeout=timeout)

    func = func[0]

    @wraps(func)
    def inner(self):
        loop = Loop.create()

        coro = func(self)

        if not iscoroutine(coro):
            raise Exception("{} is not a coroutine".format(coro))

        loop.next_tick(coro)

        if timeout:
            def stop_loop():
                loop.stop()
                raise Exception("timeout")
            timer = loop.set_timeout(stop_loop, timeout)
            # Don't wait for the timout to exit the loop
            timer.unref()

        loop.run()
        loop.close()

        assert coro.cr_await is None, 'coroutine {} should not be running'.format(coro)


    return inner

def sleep(timeout):
    return Timer(None, timeout)


def release():
    """
    Release the currect execution context and return to it in the next tick of the
    event loop
    """

    return Idle(None)

