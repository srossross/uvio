from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle

import inspect

cdef class Idle(Handle):
    cpdef Loop loop
    cpdef object coro
    cpdef object once


    def __init__(self, loop, once=True):
        self.loop = loop
        self.once = once

    def start(self, coro):

        self.coro = coro
        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_idle_t));
        uv_idle_init(self.loop.uv_loop, <uv_idle_t*> self.uv_handle);
        self.uv_handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)
        uv_idle_start(<uv_idle_t*> self.uv_handle, <uv_idle_cb> uv_python_callback);

    def stop(self):
        uv_idle_stop(<uv_idle_t*> self.uv_handle)

    def __call__(self):
        if self.once:
            self.stop()

        if inspect.iscoroutine(self.coro):
            try:
                value = self.callback.send(None)
            except StopIteration:
                pass
            value.start(self.callback)
        else:
            self.callback()
