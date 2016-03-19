from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from .uv cimport *

from .handle cimport Handle
from .request cimport Request

import sys
import inspect

cdef void ticker_callback(uv_idle_t* handle) with gil:
    loop = <object> handle.loop.data
    try:
        loop.tick()
    except BaseException as err:
        loop.catch(err)


cdef object uv_python_strerror(int code):
    msg = <char*> uv_strerror(code)
    return msg.decode()


cdef void idle_callback(uv_idle_t* handle) with gil:
    idle = <object> handle.data
    loop = <object> handle.loop.data
    loop.idle_callback(idle)

cdef void listen_callback(uv_stream_t* handle, int status) with gil:
    stream = <object> handle.data
    loop = <object> handle.loop.data
    loop.listen_callback(stream, status)


cdef void walk_callback(uv_handle_t* uv_handle, void* arg):
    callback = <object> arg

    if not uv_handle.data:
        return

    handle = <object> uv_handle.data

    try:
        callback(handle)
    except BaseException as err:
        loop = <object> uv_handle.loop.data
        loop.catch(err)


# cdef void uv_python_callback(uv_handle_t* handle) with gil:
#     callback = <object> handle.data
#     try:
#         callback.set_completed()
#     except BaseException as err:
#         loop = <object> handle.loop.data
#         loop.catch(err)

#     Py_DECREF(callback)

cdef class Loop:


    def run(self):

        #clear exceptions
        self._exceptions[:] = []

        uv_idle_init(self.uv_loop, &self.uv_tick);

        uv_idle_start(&self.uv_tick, ticker_callback);

        with nogil:
            uv_run(self.uv_loop, UV_RUN_DEFAULT)

        uv_idle_stop(&self.uv_tick)
        uv_close(<uv_handle_t*> &self.uv_tick, NULL)

        if self.exceptions:
            value = self.exceptions[0][1]
            raise value


    def alive(self):
        return bool(uv_loop_alive(self.uv_loop))

    def stop(self):
        return uv_stop(self.uv_loop)

    def close(self):
        return uv_loop_close(self.uv_loop)

    def walk(self, object callback):
        uv_walk(self.uv_loop, walk_callback, <void*> callback)
        for exc_info in self.exceptions:
            raise exc_info[1]

    def unref_ticker(self):
        uv_unref(<uv_handle_t*> &self.uv_tick)

    def ref_ticker(self):
        uv_ref(<uv_handle_t*> &self.uv_tick)

    @classmethod
    def create(cls, name='?'):
        cdef uv_loop_t* uv_loop = <uv_loop_t *> malloc(sizeof(uv_loop_t));
        uv_loop_init(uv_loop)


        cdef Loop loop = cls(name)
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
            loop = cls(name='default')
            loop.uv_loop = uv_loop
            uv_loop.data = <void*> <object> loop

            # TODO: check that this is right? this means the that default loop
            # will never get garbage collected
            Py_INCREF(<object> loop)

        return loop
