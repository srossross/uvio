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
        return


    handle = <object> _handle.data
    handle.completed()
    return


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
            int((self.timeout or 0) * 1000),
            int((self.repeat or 0) * 1000)
        )

        return self

    def __uv_complete__(self):
        self._completed = time.time()

        if self._callback:
            value = self._callback()

            if inspect.iscoroutine(value):
                self.loop.next_tick(value)

        if self.is_active():
            self.loop.awaiting(self)


    def __repr__(self):
        return "<uv.Timer active={} timout={:.4f}s callback={}>".format(
            self.is_active(), self.timeout, self._callback
        )


