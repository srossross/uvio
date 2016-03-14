
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
# from cpython.pystate cimport PyGILState_STATE, PyGILState_Ensure, PyGILState_Release

from .uv cimport *
from .loop cimport Loop, uv_python_callback
from .request cimport Request

import sys
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

    worker._set_unactive()


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

    def _uv_start(Request self, Loop loop):

        self._set_active()

        PyEval_InitThreads()

        uv_queue_work(loop.uv_loop, &self.req.work, python_worker_start, python_worker_cleanup);


