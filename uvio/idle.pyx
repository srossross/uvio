from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle

from .loop cimport Loop
import inspect

cdef class Idle(Handle):
    cpdef object coro
    cpdef object once


    def __init__(self, once=True):
        self.once = once


    def start(self, Loop loop, coro):

        if self.is_active():
            raise RuntimeError("This handle is already active")

        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_idle_t));
        uv_idle_init(loop.uv_loop, <uv_idle_t*> self.uv_handle);

        self.coro = coro
        self.uv_handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)
        uv_idle_start(<uv_idle_t*> self.uv_handle, <uv_idle_cb> uv_python_callback);

    def stop(self):
        uv_idle_stop(<uv_idle_t*> self.uv_handle)

    def __call__(self):
        if self.once:
            self.stop()
        else:
            Py_INCREF(<object> self)

        if inspect.iscoroutine(self.coro):
            try:
                value = self.coro.send(None)
                value.start(self.loop, self.coro)
            except StopIteration:
                pass
        else:
            self.coro()


