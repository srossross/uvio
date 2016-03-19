from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from ._loop cimport Loop
from .handle cimport Handle

import inspect
import time

from .futures import Future

cdef void timer_callback(uv_timer_t* _handle) with gil:

    if not _handle.data:
        raise RuntimeError("uv idle callback recieved NULL python object")

    handle = <object> _handle.data
    try:
        handle.__uv_complete__()
    except BaseException as err:
        handle.loop.catch(err)
    else:
        handle.loop.completed(handle)



async def sleep(timeout):
    await Timer(None, timeout)


class Timer(Handle, Future):

    def __init__(Handle self, callback, timeout, repeat=False):

        self.timeout = timeout
        self.repeat = repeat
        self._callback = callback


    def __uv_init__(Handle self, Loop loop):
        uv_timer_init(loop.uv_loop, &self.handle.timer);
        self.handle.handle.data = <void*> self

    def __uv_start__(Handle self):

        self._started = time.time()

        uv_timer_start(
            &self.handle.timer,
            timer_callback,
            int(self.timeout * 1000),
            int(self.repeat * 1000)
        )

        return self

    def __uv_complete__(self):
        self._completed = time.time()

        if self._callback:
            self._callback()

    def __repr__(self):
        return "<uv.Timer active={} timout={:.4f}s callback={}>".format(
            self.is_active(), self.timeout, self._callback
        )


