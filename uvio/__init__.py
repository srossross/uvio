from functools import wraps, partial
from inspect import iscoroutine
from .loop import Loop, get_current_loop
from .timer import Timer
from .idle import Idle
from .workers import worker
from .stream import Stream

from . import fs
from . import net
from . import process

get_default_loop = Loop.get_default_loop


def sync(*func, timeout=None):
    """
    coroutine decorator, convert a coroutine into a syncronous function::

        @sync(timeout=2)
        async def main(sleep_for):
            await uvio.sleep(sleep_for)
            return 'main returned ok!'

        print(main(1))

    """
    if not func:
        return partial(sync, timeout=timeout)

    func = func[0]

    @wraps(func)
    def inner(*args, **kwargs):
        loop = Loop.create(func.__name__)

        coro = func(*args, **kwargs)

        if not iscoroutine(coro):
            raise Exception("{} is not a coroutine (returned from {})".format(coro, func))

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

        if timeout:
            timer.close()

        if coro.cr_await is not None:
            coro.throw(Exception('coroutine {} should not be running at the end of the loop'.format(coro)))

        # This should not happend
        assert not loop._awaiting, loop._awaiting
        assert not loop.ready, loop.ready

    return inner


def sleep(timeout):
    '''Coroutine that completes after a given time (in seconds).
    '''
    return Timer(None, timeout)


async def set_timeout(func, timeout, repeat=None):
    '''Coroutine that starts after a given time (in seconds).
    '''
    loop = await get_current_loop()
    return loop.set_timeout(func, timeout, repeat=repeat)


async def next_tick(func, *args, **kwargs):
    '''Coroutine that starts after being idle
    '''
    loop = await get_current_loop()
    return loop.next_tick(func, *args, **kwargs)


from ._version import get_versions
__version__ = get_versions()['version']
del get_versions
