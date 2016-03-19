from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from ._loop cimport Loop
from .handle cimport Handle

import inspect
from .futures import Future

cdef void idle_callback(uv_idle_t* _handle) with gil:

    if not _handle.data:
        raise RuntimeError("uv idle callback recieved NULL python object")

    handle = <object> _handle.data
    try:
        handle.__uv_complete__()
    except BaseException as err:
        handle.loop.catch(err)
    else:
        handle.loop.completed(handle)


class Idle(Handle, Future):


    def __init__(Handle self, callback, once=True):
        self.once = once
        self._callback = callback

    def stop(Handle self):
        uv_idle_stop(&self.handle.idle)

    def __uv_init__(Handle self, Loop loop):
        uv_idle_init(loop.uv_loop, &self.handle.idle)
        self.handle.handle.data = <void*> self

    def __uv_start__(Handle self):

        uv_idle_start(&self.handle.idle, idle_callback)


    def __uv_complete__(self):

        if self.once:

            self.stop()

        if (self._callback):
            return self._callback()


