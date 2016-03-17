from __future__ import print_function

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from uv cimport *

cdef void idle_callback(uv_idle_t* _handle) with gil:
    handle = <object> _handle.data
    handle.step()

cdef void timer_callback(uv_timer_t* _handle) with gil:
    print("timer_callback", <int> _handle.data)
    if not _handle.data:
        raise Exception("timer callback")
    handle = <object> _handle.data
    print("handle", handle)
    handle.step()



class get_current_loop:
    _done = False
    def done(self):
        return self._done

    def __await__(self):
        self._done = True
        print("get_current_loop.__dict__", dir(self))

        yield self

        return self.loop


cdef class Loop:
    cdef uv_loop_t* uv_loop
    cpdef object _active_handles
    cpdef object _pending_coroutines
    cpdef object _exceptions

    property active_handles:
        def __get__(self):
            return self._active_handles

    property pending_coroutines:
        def __get__(self):
            return self._pending_coroutines

    def __init__(self):
        self._active_handles = set()
        self._pending_coroutines = set()

    def catch(self, err):
        print(err)
        raise err

    def next_tick(self, coro):
        self._pending_coroutines.add(coro)

    def run(self):
        while self._pending_coroutines:
            coro = self._pending_coroutines.pop()
            print("run.send coro", coro)
            continuation = coro.send(None)
            continuation.coro = coro
            continuation.loop = self
            print("continuation.loop")

            with nogil:
                uv_run(self.uv_loop, UV_RUN_DEFAULT)

def get_default_loop():

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

cdef class Handle:

    cdef uv_any_handle handle
    cpdef object _coro
    cpdef object _loop
    cpdef object _done


    property coro:
        def __get__(self):
            return self._coro
        def __set__(self, value):
            self._coro = value
        def __del__(self):
            self._coro = None

    def done(self):
        return self._done

    property loop:
        def __get__(self):
            if <int> self.handle.handle.loop:
                return <object> self.handle.handle.loop.data

        def __set__(self, value):
            pass

    def __uv_complete__(self, *args):
        print("__uv_complete__", self)
        return None


    def __await__(self):
        print("__iter__")
        if self.done():
            raise Exception("future has already be awaited")


        self.handle.handle.data = <void*> self
        print("set handle data", <int> self.handle.handle.data)
        self.loop.active_handles.add(self)

        self.__uv_start__()
        print("__iter__.started")
        args = yield self
        print("__iter__: yielded args", args)
        result = self.__uv_complete__(*args)

        self._done = True

        del self.coro
        print("__iter__: returns", result)

        self.handle.handle.data = NULL


        return result

    def step(self, *args):

        import traceback
        print('-- stack --')
        traceback.print_stack()
        print('--')
        print("step", args)

        coro = self.coro


        del self.coro

        continuation = None

        while 1:
            print("step loop -")
            try:
                print("step.send coro", coro, args)
                continuation = coro.send(args)

            except StopIteration:
                print("StopIteration")
                self.loop.active_handles.discard(self)
                return
            except BaseException as err:
                self.loop.catch(err)
                return

            continuation.loop = self.loop
            continuation.coro = coro

            if not continuation.done():
                return


cdef class Idle(Handle):



    def __init__(self, Loop loop):
        uv_idle_init(loop.uv_loop, &self.handle.idle);

    def stop(self):
        uv_idle_stop(&self.handle.idle)

    def __uv_start__(self):
        print("Idle.__uv_start__")
        uv_idle_start(&self.handle.idle, idle_callback)

    def __uv_complete__(self, *args):
        print("Idle.__uv_complete__")
        self.stop()

    def __iter__(self):
        self.__uv_start__()
        args = yield self
        result = self.__uv_complete__(*args)
        self._coro = None
        return result


    def __await__(self):
        if self._coro:
            raise Exception("coroutine already awaiting")

        self._coro = self.__iter__()

        return self._coro


cdef class Timer(Handle):

    cdef float timeout
    cdef float repeat

    def __init__(self, Loop loop, timeout, repeat=False):

        self.timeout = timeout
        self.repeat = repeat

        uv_timer_init(loop.uv_loop, &self.handle.timer)


    def __uv_start__(self):

        uv_timer_start(
            &self.handle.timer,
            timer_callback,
            int(self.timeout * 1000),
            int(self.repeat * 1000),
        )

    def __repr__(self):
        return "<uv.Timer timout={:.4f}s>".format(
            self.timeout
        )

