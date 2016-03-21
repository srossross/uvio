
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
# from cpython.pystate cimport PyGILState_STATE, PyGILState_Ensure, PyGILState_Release

from .uv cimport *
from ._loop cimport Loop
from .request cimport Request

import sys
import inspect

from .futures import Future


cdef extern from *:
    void PyEval_InitThreads()


cdef void worker_start_callback(uv_work_t *req) with gil:
    worker = <object> req.data
    try:
        worker.execute()
    except BaseException as err:
        loop = <object> req.loop.data
        loop.catch(err)


cdef void worker_cleanup_callback(uv_work_t * _req, int status) with gil:
    if _req.data:
        req = <object> _req.data
        req.completed(status)

class worker(Request, Future):
    """worker(callback, *args, **kwargs)

    libuv provides a threadpool which can be used to run user code and get notified in the loop thread.
    This thread pool is internally used to run all filesystem operations,
    as well as getaddrinfo and getnameinfo requests.

    Its default size is 4,
    but it can be changed at startup time by setting the UV_THREADPOOL_SIZE environment variable
    to any value (the absolute maximum is 128).

    The threadpool is global and shared across all event loops.
    When a particular function makes use of the threadpool
    (i.e. when using worker()) libuv preallocates and initializes the maximum number of threads allowed by UV_THREADPOOL_SIZE.
    This causes a relatively minor memory overhead (~1MB for 128 threads) but increases the performance of threading at runtime.

    example::

        def compute(arg):
            # Blocking operation. This is not an async sleep!

            if arg > 1:
                raise TypeError("arg must be less than 1")

            time.sleep(0.05)

            return arg - 1

        @uvio.sync
        async def main():
            try:
                result = await worker(worker, -1)
            except TypeError:
                print("wow!! exceptions are passed back to the main thread?")

    """

    def __init__(self, callback, *args, **kwargs):

        self._callback = callback
        self._args = args
        self._kwargs = kwargs
        self._result = None
        self._exec_info = (None, None, None)

    def execute(self):
        """
        This will be executed in another thread
        """

        try:
            self._result = self._callback(*self._args, **self._kwargs)
        except Exception as err:
            self._exception = err


    def __uv_init__(Request self, Loop loop):
        PyEval_InitThreads()

        uv_queue_work(
            loop.uv_loop, &self.req.work,
            worker_start_callback,
            worker_cleanup_callback
        )
        self.req.req.data = <void*> self

    def __uv_start__(Request self):
        # __uv_init__ 'started'  this.. is this common for all requests?
        pass

    def __uv_complete__(Request self, status):
        # __uv_init__ 'started'  this.. is this common for all requests?
        self._done = True
        self._status = status


