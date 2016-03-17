from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop
from .handle cimport Handle

from .loop cimport Loop


import inspect
from .futures import Future

cdef void idle_callback(uv_idle_t* _handle) with gil:

    if not _handle.data:
        raise RuntimeError("uv idle callback recieved NULL python object")

    handle = <object> _handle.data
    handle.loop.step(handle)

async def wrap_function(callback):
    return callback()

class Idle(Handle, Future):


    def __init__(Handle self, Loop loop, coro, once=True):
        self.once = once

        uv_idle_init(loop.uv_loop, &self.handle.idle)
        self.handle.handle.data = <void*> self

        print("self.coro", coro)

        if not inspect.iscoroutine(coro):
            coro = wrap_function(coro)

        self.coro = coro

    def stop(Handle self):
        uv_idle_stop(&self.handle.idle)

    def __uv_start__(Handle self):

        uv_idle_start(&self.handle.idle, idle_callback)



    def __uv_complete__(self):

        if self.once:
            self.stop()

        if (self._callback):
            return self._callback()


