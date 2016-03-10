from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle

import inspect
import time

from .loop import Loop
from .futures import Future


class Timer(Handle, Future):

    def __init__(self, callback, timeout, repeat=False):

        self.timeout = timeout
        self._callback = callback
        self.repeat = repeat


    def _uv_start(Handle self, Loop loop):

        self._started = time.time()
        if self.is_active():
            raise RuntimeError("This handle is already active")

        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_timer_t))
        uv_timer_init(loop.uv_loop, <uv_timer_t*> self.uv_handle);

        self.uv_handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        uv_timer_start(
            <uv_timer_t*> self.uv_handle,
            <uv_timer_cb> uv_python_callback,
            int(self.timeout * 1000),
            self.repeat
        )

        return self


    def __repr__(self):
        return "<uv.Timer active={} timout={:.4f}s callback={}>".format(
            self.is_active(), self.timeout, self._callback
        )

    def set_completed(self):

        self._completed = time.time()

        if (self._callback):
            self._callback()

        Future.set_completed(self)
