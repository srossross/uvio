from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback

from .loop cimport Loop

import os
import inspect
import asyncio

cdef class ProcessHandle:
    pass


cdef class Popen(ProcessHandle):
    pass