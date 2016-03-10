import asyncio

from .loop import Loop
from .timer import Timer
from .idle import Idle
from .worker import Worker
from . import fs

get_default_loop = Loop.get_default_loop

@asyncio.coroutine
def sleep(arg):
    yield Timer(arg)


@asyncio.coroutine
def release():
    """
    Release the currect execution context and return to it in the next tick of the
    event loop
    """

    yield Idle()


@asyncio.coroutine
def worker(callback, *args, **kwargs):
    result = yield Worker(callback, *args, **kwargs)
    return result
