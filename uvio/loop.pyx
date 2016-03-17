from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from .uv cimport *

from .handle cimport Handle
from .request cimport Request

import sys
import inspect

from .idle import Idle
from .futures import Future


cdef void idle_run_callback(uv_idle_t* handle) with gil:
    loop = <object> handle.loop.data
    loop.tick()


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


cdef void python_walk_cb(uv_handle_t* uv_handle, void* arg):
    callback = <object> arg
    if uv_handle.data:
        handle = <object> uv_handle.data

    try:
        callback(handle)
    except BaseException as err:
        loop = <object> uv_handle.loop.data
        loop.catch(err)


cdef void uv_python_callback(uv_handle_t* handle) with gil:
    callback = <object> handle.data
    try:
        callback.set_completed()
    except BaseException as err:
        loop = <object> handle.loop.data
        loop.catch(err)

    Py_DECREF(callback)

async def wrap_function(callback):
    return callback()

cdef class Loop:

    def __init__(self):
        self._exceptions = []
        self._exception_handler = None
        self._active_handles = set()
        self._pending_coroutines = set()
        self._reqs = set()

    property active_handles:
        def __get__(self):
            return self._active_handles

    property pending_coroutines:
        def __get__(self):
            return self._pending_coroutines




    # def idle_callback(self, idle):
    #     "Called after idle.start"
    #     self._handles.discard(idle)

    #     try:
    #         idle.set_completed()
    #     except BaseException as err:
    #         self.catch(err)

    # def new_connection_callback(self, stream, status):

    #     # Don't have to remove handle stream from _handles

    #     if status < 0:
    #         err = IOError(status, "Cound not create new connection: {}".format(uv_strerror(status).decode()))
    #         self.catch(err)
    #         return

    #     try:
    #         stream.accept()
    #     except BaseException as err:
    #         self.catch(err)

    # def connect_callback(self, request, status):

    #     self._reqs.discard(request)

    #     if status < 0:
    #         msg = uv_strerror(status).decode()
    #         err = IOError(status, "Network Connection error: {}".format(msg))
    #     else:
    #         err = None

    #     try:
    #         request.set_completed(err)
    #     except BaseException as err:
    #         self.catch(err)


    def next_tick(self, callback):
        if inspect.iscoroutine(callback):
            self.pending_coroutines.add(callback)
        elif inspect.iscoroutinefunction(callback):
            raise Exception("Did you mean ot create a coroutine ? got a coroutine function")
        else:
            self.pending_coroutines.add(wrap_function(callback))

    # def set_timeout(self, callback, timeout, repeat=False):
    #     py_timer = Timer(self, callback, timeout, repeat)
    #     py_timer.start()
    #     self.active_handles.add(py_timer)
    #     return py_timer

    def __repr__(self):
        return "<uvio.Loop alive={}>".format(self.alive())

    property exceptions:
        def __get__(self):
            return self._exceptions

    def catch(self, err):
        etype, evalue, traceback = sys.exc_info()
        if evalue is None:
            evalue = err

        self._exceptions.append((etype, evalue, traceback))

    def run(self):

        #clear exceptions
        self._exceptions[:] = []

        uv_idle_init(self.uv_loop, &self.uv_tick);

        uv_idle_start(&self.uv_tick, idle_run_callback);

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

    def walk(self, object callback):
        uv_walk(self.uv_loop, python_walk_cb, <void*> callback)
        for exc_info in self.exceptions:
            raise exc_info[1]

    property exception_handler:
        def __get__(self):
            return self._exception_handler

        def __set__(self, value):
            self._exception_handler = value

    def tick(self):

        self.handle_exceptions()

        if not self._pending_coroutines:
            # Don't block the loop from exiting
            uv_unref(<uv_handle_t*> &self.uv_tick)
            return

        print("pending_coroutines")
        coroutine = self._pending_coroutines.pop()
        print("coroutine", coroutine)

        try:
            continuation = coroutine.send(None)


        except StopIteration:
            print("stop")
        except BaseException as err:
            self.catch(err)
        else:
            print("continuation", continuation)
            continuation.loop = self
            continuation.coro = coroutine
            self.step(continuation)

    def step(self, continuation, *args):

        coro = continuation.coro

        if coro is None:
            # This is not done
            return

        print("continuation", continuation)
        print("coro", coro)

        del continuation.coro

        while 1:

            try:

                if coro.cr_await is None:
                    assert not args
                    args = None

                continuation = coro.send(args)


            except StopIteration:
                self.active_handles.discard(self)
                return

            except BaseException as err:
                self.catch(err)
                return

            args = None
            continuation.loop = self
            continuation.coro = coro

            if not continuation.done():
                return




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

class get_current_loop:
    _done = False

    def done(self):
        return self._done

    def __await__(self):
        print("get_current_loop.__await__...")
        self._done = True
        yield self
        return self.loop
        print("get_current_loop.__await__.done")
