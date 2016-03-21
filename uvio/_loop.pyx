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


cdef class Loop:


    def run(self, once=False, blocking=False):
        """loop.run(once=False, blocking=False)

        This function runs the event loop. It will act differently depending on the specified mode:
        Runs the event loop until there are no more active and referenced handles or requests.

        :param once: Poll for i/o once. Note that this function blocks if there are no pending callbacks.
        :param blocking: Poll for i/o once but don’t block if there are no pending callbacks.

        If run returns True then there are pending requests waiting to be handled
        (meaning you should run the event loop again sometime in the future).
        """
        #clear exceptions
        self._exceptions[:] = []

        uv_idle_init(self.uv_loop, &self.uv_tick);

        uv_idle_start(&self.uv_tick, ticker_callback);

        cdef uv_run_mode mode =  UV_RUN_DEFAULT
        if blocking:
            mode = UV_RUN_NOWAIT
        elif once:
            mode = UV_RUN_ONCE

        cdef int result
        with nogil:
            result = uv_run(self.uv_loop, mode)

        uv_idle_stop(&self.uv_tick)
        uv_close(<uv_handle_t*> &self.uv_tick, NULL)

        if self.exceptions:
            value = self.exceptions[0][1]
            raise value

        return bool(result)


    def alive(self):
        'Test if there are active handles or request in the loop.'
        return bool(uv_loop_alive(self.uv_loop))

    def stop(self):
        '''
        Stop the event loop, causing loop.run() to end as soon as possible.
        This will happen not sooner than the next loop iteration.
        If this function was called before blocking for i/o, the loop won’t block for i/o on this iteration.

        '''
        return uv_stop(self.uv_loop)

    def close(self):
        '''
        Releases all internal loop resources.
        Call this function only when the loop has finished executing and all open handles and requests have been closed,
        or it will raise UVBusy.
        '''

        return uv_loop_close(self.uv_loop)

    def walk(self, object callback):
        '''walk(walk_cb)

        Walk the list of handles: walk_cb will be called for each handle.
        '''
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
