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
        loop = Loop.create(func.__name__)

        coro = func(self)

        if not iscoroutine(coro):
            raise Exception("{} is not a coroutine (returned from {})".format(coro, func))

        loop.next_tick(coro)

        if timeout:
            def stop_loop():
                loop.stop()

                print('loop._awaiting', loop._awaiting)
                print('loop.ready', loop.ready)
                print('-+')
                @loop.walk
                def walk(h):
                    print("handle", h)
                print('-+')
                raise Exception("timeout")
            timer = loop.set_timeout(stop_loop, timeout)
            # Don't wait for the timout to exit the loop
            timer.unref()

        loop.run()
        loop.close()


        if coro.cr_await is not None:
            coro.throw(Exception('coroutine {} should not be running at the end of the loop'.format(coro)))

        print(loop._awaiting)
        print(loop.ready)



    return inner

def sleep(timeout):
    return Timer(None, timeout)


def release():
    """
    Release the currect execution context and return to it in the next tick of the
    event loop
    """

    return Idle(None)

