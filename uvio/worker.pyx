
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
# from cpython.pystate cimport PyGILState_STATE, PyGILState_Ensure, PyGILState_Release

from .uv cimport *
from .loop cimport Loop, uv_python_callback

import sys
import asyncio
import inspect

from .futures import Future


cdef extern from *:
    void PyEval_InitThreads()


cdef void python_worker_start(uv_work_t *req) with gil:

    worker = <object> req.data
    try:
        worker.execute()
    except BaseException as err:
        loop = <object> req.loop.data
        loop.catch(err)


cdef void python_worker_cleanup(uv_work_t *req, int status) with gil:

    worker = <object> req.data
    try:
        worker.set_completed()
    except BaseException as err:
        loop = <object> req.loop.data
        loop.catch(err)

    Py_DECREF(worker)


cdef class _Worker:
    cdef uv_work_t* req


class Worker(_Worker, Future):

    def __init__(self, callback, *args, **kwargs):

        self._callback = callback
        self._args = args
        self._kwargs = kwargs
        self._result = None
        self._exec_info = (None, None, None)
        self._is_active = False

    def is_active(self):
        return self._is_active and not self._done

    def execute(self):
        """
        This will be executed in another thread
        """

        try:
            self._result = self._callback(*self._args, **self._kwargs)
        except Exception as err:
            self._exec_info = sys.exc_info()

    def _uv_start(_Worker self, Loop loop):

        self._is_active = True

        self.req = <uv_work_t *> malloc(sizeof(uv_work_t))

        self.req.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        PyEval_InitThreads()

        uv_queue_work(loop.uv_loop, self.req, python_worker_start, python_worker_cleanup);

    # def __call__(self):


    #     if inspect.iscoroutine(self.coro):
    #         try:
    #             if self._exec_info[1]:
    #                 self.coro.throw(*self._exec_info)
    #             else:
    #                 value = self.coro.send(self._result)
    #                 value.start(self.loop, self.coro)
    #         except StopIteration:
    #             pass
    #     else:
    #         if self._exec_info[1]:
    #             raise self._exec_info[1]

    #         self.coro()

