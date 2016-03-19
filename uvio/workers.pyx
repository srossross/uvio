
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


    req = <object> _req.data
    try:
        req.__uv_complete__(status)
    except BaseException as err:
        req.loop.catch(err)
    else:
        req.loop.completed(req)

class worker(Request, Future):

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
            self._exec_info = sys.exc_info()


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


