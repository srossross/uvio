from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .handle cimport Handle

from .loop import Loop
import inspect

cdef class Timer(Handle):

    cpdef object coro
    cpdef float timeout
    cpdef int repeat

    def __init__(self, timeout, repeat=False):

        self.timeout = timeout
        self.repeat = repeat
        self.coro = None

    def start(self, Loop loop, coro):


        if self.is_active():
            raise RuntimeError("This handle is already active")

        self.uv_handle = <uv_handle_t *> malloc(sizeof(uv_timer_t))
        uv_timer_init(loop.uv_loop, <uv_timer_t*> self.uv_handle);


        self.coro = coro
        self.uv_handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        uv_timer_start(
            <uv_timer_t*> self.uv_handle,
            <uv_timer_cb> uv_python_callback,
            int(self.timeout * 1000),
            self.repeat
        )



    def __call__(self):
        if inspect.iscoroutine(self.coro):
            try:
                value = self.coro.send(None)
            except StopIteration:
                pass
        else:
            self.coro()

    def __repr__(self):
        return "<uv.Timer active={} timout={:.4f}s callback={}>".format(
            self.is_active(), self.timeout, self.coro
        )

