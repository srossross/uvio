from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle

from .loop cimport Loop
from .futures import Future

import inspect

class Idle(Handle, Future):


    def __init__(self, callback, once=True):
        self.once = once

        if inspect.iscoroutine(callback):
            self._coro = callback
            self._callback = None
        else:
            self._callback = callback


    def _uv_start(Handle self, Loop loop):

        if self.is_active():
            raise RuntimeError("This handle is already active")


        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_idle_t));
        uv_idle_init(loop.uv_loop, <uv_idle_t*> self.uv_handle);

        self.uv_handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        uv_idle_start(<uv_idle_t*> self.uv_handle, <uv_idle_cb> uv_python_callback);

    def stop(Handle self):
        uv_idle_stop(<uv_idle_t*> self.uv_handle)

    def set_completed(self):
        if self.once:
            self.stop()
        else:
            Py_INCREF(<object> self)

        if (self._callback):
            self._callback()

        Future.set_completed(self)


