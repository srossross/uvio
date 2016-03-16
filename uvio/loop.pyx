from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from .uv cimport *

from .handle cimport Handle
from .request cimport Request
import sys

from .idle import Idle
from .timer import Timer
from .futures import Future


cdef void uv_python_handle_exceptions(uv_idle_t* handle) with gil:
    loop = <object> handle.loop.data
    loop.handle_exceptions()


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


cdef class Loop:

    def __init__(self):
        self._exceptions = []
        self._exception_handler = None
        self._handles = set()
        self._reqs = set()

    def _add_handle(self, Handle handle):
        handle.handle.handle.data = <void*> handle
        self._handles.add(handle)

    def _add_req(self, Request req):
        req.req.req.data = <void*> req
        self._reqs.add(req)

    def idle_callback(self, idle):
        "Called after idle.start"
        self._handles.discard(idle)

        try:
            idle.set_completed()
        except BaseException as err:
            self.catch(err)

    def new_connection_callback(self, stream, status):

        # Don't have to remove handle stream from _handles

        if status < 0:
            err = IOError(status, "Cound not create new connection: {}".format(uv_strerror(status).decode()))
            self.catch(err)
            return

        try:
            stream.accept()
        except BaseException as err:
            self.catch(err)

    def connect_callback(self, request, status):

        self._reqs.discard(request)

        if status < 0:
            msg = uv_strerror(status).decode()
            err = IOError(status, "Network Connection error: {}".format(msg))
        else:
            err = None

        try:
            request.set_completed(err)
        except BaseException as err:
            self.catch(err)


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
        etype, evalue, traceback = sys.exc_info()
        if evalue is None:
            evalue = err

        self._exceptions.append((etype, evalue, traceback))

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

    def walk(self, object callback):
        uv_walk(self.uv_loop, python_walk_cb, <void*> callback)
        for exc_info in self.exceptions:
            raise exc_info[1]

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

class get_current_loop(Future):
    _is_active = False

    def _uv_start(self, loop):

        self._is_active = True
        self._result = loop
        if self._coro:
            loop.next_tick(self._coro)

    def is_active(self):
        return self._is_active





