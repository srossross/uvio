from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
import inspect
import asyncio

from uv cimport *
from .handle cimport Handle

from .futures import Future


cdef void uv_python_callback(uv_handle_t* handle):

    callback = <object> handle.data
    callback()
    Py_DECREF(callback)



cdef class AsyncFile:
    cpdef Loop loop
    cdef uv_fs_t* handle

    def __init__(self, Loop loop, char* path, int flags, int mode):

        self.handle = <uv_fs_t *> malloc(sizeof(uv_fs_t))
        uv_fs_open(self.loop.uv_loop, self.handle, path, flags, mode, NULL)

    def close(self):
        # uv_fs_open(self.loop.uv_loop, self.handle, path, flags, mode, NULL)
        pass

    @asyncio.coroutine
    def read(self, n=-1):
        yield FSRead(self.loop, self, n)

cdef class FSRead(Future):

    cpdef Loop loop
    cpdef AsyncFile afile
    cpdef int n

    def __init__(self, Loop loop, AsyncFile afile, int n):
        self.loop = loop
        self.afile = afile
        self.n = n
        self.buffer = bytearray()

    def start(self, coro):


        # cdef iov = uv_buf_init(buffer, sizeof(buffer))

        # handle.data = <void*> (<PyObject*> self)

        # uv_fs_read(
        #     self.loop.uv_loop,
        #     handle, handle.result,
        #     &iov, 1, -1, <uv_fs_cb> uv_python_callback
        # )
        pass

    def stop(self, coro):
        pass

    def __call__(self):
        pass




cdef class Idle(Future):
    cpdef Loop loop
    cpdef object coro
    cpdef object once

    cdef uv_idle_t* handle

    def __init__(self, loop, once=True):
        self.loop = loop
        self.once = once

    def start(self, coro):

        self.coro = coro
        self.handle = <uv_idle_t *> malloc(sizeof(uv_idle_t));
        uv_idle_init(self.loop.uv_loop, self.handle);
        self.handle.data = <void*> (<PyObject*> self)
        Py_INCREF(self)
        uv_idle_start(self.handle, <uv_idle_cb> uv_python_callback);

    def stop(self):
        uv_idle_stop(self.handle)

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



cdef class Timer(Future):

    cpdef Loop loop
    cpdef object callback
    cpdef int timeout
    cpdef int repeat

    def __init__(self, loop, timeout, repeat=False):
        self.loop = loop

        self.timeout = int(timeout * 1000)
        self.repeat = repeat

    def start(self, callback):
        self.callback = callback

        cdef uv_timer_t *uv_timer = <uv_timer_t *> malloc(sizeof(uv_timer_t))
        uv_timer_init(self.loop.uv_loop, uv_timer);
        uv_timer.data = <void*> (<PyObject*> self)
        Py_INCREF(self)
        uv_timer_start(uv_timer, <uv_timer_cb> uv_python_callback, <int> self.timeout, <int> self.repeat)



    def __call__(self):
        if inspect.iscoroutine(self.callback):
            try:
                value = self.callback.send(None)
            except StopIteration:
                return
            value.start(self.callback)
        else:
            self.callback()

    def __repr__(self):
        return "<uv.Timer timout={} callback={}>".format(self.timeout, self.callback)

get_default_loop = Loop.get_default_loop



