from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop
from .handle cimport Handle

import inspect
import time

from .loop import get_current_loop
from .futures import Future

cdef void timer_callback(uv_timer_t* _handle) with gil:

    if not _handle.data:
        raise RuntimeError("uv idle callback recieved NULL python object")

    handle = <object> _handle.data
    print("timer_callback handle", handle)
    handle.loop.step(handle)



async def sleep(timeout):
    loop = await get_current_loop()
    print("loop", loop)
    await Timer(loop, None, timeout)
    print("timer")
    return


def wrap_function(callback):
    yield
    return callback()

class Timer(Handle, Future):

    def __init__(Handle self, Loop loop, coro, timeout, repeat=False):

        self.timeout = timeout
        self.repeat = repeat

        if not inspect.iscoroutine(coro):
            coro = wrap_function(coro)
            coro.send(None)

        self.coro = coro

        uv_timer_init(loop.uv_loop, &self.handle.timer);
        self.handle.handle.data = <void*> self


    def __uv_start__(Handle self):
        print('timer __uv_start__')

        self._started = time.time()

        uv_timer_start(
            &self.handle.timer,
            timer_callback,
            int(self.timeout * 1000),
            int(self.repeat * 1000)
        )

        return self

    def __uv_complete__(self):
        print('timer __uv_complete__')
        self._completed = time.time()

    def __repr__(self):
        return "<uv.Timer active={} timout={:.4f}s coro={}>".format(
            self.is_active(), self.timeout, self.coro
        )


