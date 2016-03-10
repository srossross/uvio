from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from .uv cimport *

import sys

from .idle import Idle
from .timer import Timer


cdef void uv_python_handle_exceptions(uv_idle_t* handle) with gil:
    loop = <object> handle.loop.data
    loop.handle_exceptions()


cdef void uv_python_callback(uv_handle_t* handle) with gil:
    callback = <object> handle.data
    try:
        callback.set_completed()
    except BaseException as err:
        loop = <object> handle.loop.data
        loop.catch(err)

    Py_DECREF(callback)


cdef class Loop:

    def __init__(self):
        self._exceptions = []
        self._exception_handler = None

    def next_tick(self, callback):
        idle = Idle(callback)
        idle.start(self)
        return idle

    def set_timeout(self, callback, timeout, repeat=False):
        py_timer = Timer(callback, timeout, repeat)
        py_timer.start(self)
        return py_timer

    def __repr__(self):
        return "<uvio.Loop alive={}>".format(self.alive())

    property exceptions:
        def __get__(self):
            return self._exceptions

    def catch(self, err):
        self._exceptions.append(sys.exc_info())

    def run(self):

        #clear exceptions
        self._exceptions[:] = []

        cdef uv_idle_t* uv_handle = <uv_idle_t *> malloc(sizeof(uv_idle_t));
        uv_idle_init(self.uv_loop, uv_handle);

        # Don't block the loop from exiting
        uv_unref(<uv_handle_t*> uv_handle)

        uv_idle_start(uv_handle, uv_python_handle_exceptions);

        with nogil:
            uv_run(self.uv_loop, UV_RUN_DEFAULT)

        if self.exceptions:
            value = self.exceptions[0][1]
            raise value

    def close(self):
        uv_loop_close(self.uv_loop)

    def __enter__(self):
        self.run()
        return self

    def __exit__(self, *args):
        self.close()
        return

    async def sleep(self, miliseconds):
        pass

    def alive(self):
        return bool(uv_loop_alive(self.uv_loop))

    def stop(self):
        uv_stop(self.uv_loop)

    property exception_handler:
        def __get__(self):
            return self._exception_handler

        def __set__(self, value):
            self._exception_handler = value

    def handle_exceptions(self):

        while self.exceptions:
            if self.exception_handler is None:
                return self.stop()

            try:
                self.exception_handler(*self.exceptions[0])
            except BaseException:
                return self.stop()
            else:
                self.exceptions.pop(0)

    @classmethod
    def create(cls):
        cdef uv_loop_t* uv_loop = <uv_loop_t *> malloc(sizeof(uv_loop_t));
        uv_loop_init(uv_loop)


        loop = Loop()
        loop.uv_loop = uv_loop
        uv_loop.data = <void*> <object> loop

        # TODO: check that this is right? this means the that default loop
        # will never get garbage collected
        Py_INCREF(<object> loop)

        return loop

    @classmethod
    def get_default_loop(cls):

        cdef Loop loop
        cdef uv_loop_t* uv_loop = uv_default_loop()

        if <int> uv_loop.data:
            loop = <object> uv_loop.data
        else:
            loop = Loop()
            loop.uv_loop = uv_loop
            uv_loop.data = <void*> <object> loop

            # TODO: check that this is right? this means the that default loop
            # will never get garbage collected
            Py_INCREF(<object> loop)


        return loop
