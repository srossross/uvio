import asyncio

from .loop import Loop
from .timer import Timer
from .idle import Idle
from . import fs

get_default_loop = Loop.get_default_loop

@asyncio.coroutine
def sleep(arg):
    yield Timer(arg)


@asyncio.coroutine
def release():
    yield Idle()
