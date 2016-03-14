from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback, uv_python_strerror

from .loop cimport Loop

import os
import inspect
import asyncio

from .futures import Future

cdef class FileHandle:
    cdef uv_fs_t* uv_fs

    property result:
        def __get__(self):
            return (<int>self.uv_fs) and self.uv_fs.result

    property loop:
        def __get__(self):
            if <int> self.uv_fs:
                return <object> self.uv_fs.loop.data

cdef void uv_python_fs_callback(uv_fs_t* handle) with gil:

    callback = <object> handle.data
    try:
        callback.set_completed()
    except BaseException as err:
        loop = <object> handle.loop.data
        loop.catch(err)

    Py_DECREF(callback)

class Read(FileHandle, Future):


    def __init__(self, fileno, n):
        self.fileno = fileno
        self.n = n
        self.buf = bytearray(n)
        self._is_active = False

    def result(self):
        return self.buf.decode()

    def is_active(self):
        return self._is_active and not self._done

    def _uv_start(FileHandle self, Loop loop):

        self._is_active = True

        self.uv_fs = <uv_fs_t *> malloc(sizeof(uv_fs_t));

        self.uv_fs.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        cdef uv_buf_t bufs = uv_buf_init(self.buf, self.n)

        uv_fs_read(
            loop.uv_loop, self.uv_fs, self.fileno,
            &bufs, 1, -1, uv_python_fs_callback
        )



cdef class AsyncFile(FileHandle):

    cpdef object filename
    cpdef object mode
    cpdef Loop _loop


    def __init__(self, Loop loop, filename, mode):

        self.filename = filename
        self.mode = mode

        #O_RDONLY, O_WRONLY, or O_RDWR

        self.uv_fs = <uv_fs_t *> malloc(sizeof(uv_fs_t))

        self._loop = loop

        uv_fs_open(
            loop.uv_loop,
            self.uv_fs,
            filename.encode(), 0, O_RDONLY, NULL
        )

        if self.uv_fs.result < 0:
            raise IOError(self.uv_fs.result, uv_python_strerror(self.uv_fs.result))


    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def close(self):

        cdef uv_fs_t close_handle

        uv_fs_close(
            self.uv_fs.loop,
            &close_handle,
            self.uv_fs.result,
            NULL
        )

    def _size(self):
        cdef uv_fs_t stat_handle
        uv_fs_fstat(self.uv_fs.loop, &stat_handle, self.uv_fs.result, NULL)
        if stat_handle.result < 0:
            msg = uv_strerror(stat_handle.result).decode()
            raise IOError(stat_handle.result, msg)

        return stat_handle.statbuf.st_size

    def read(self, n=-1):

        if n <= 0:
            n = self._size()

        return Read(self.uv_fs.result, n)


def fstat(FileHandle fd):

    cdef uv_fs_t stat_handle
    uv_fs_fstat(fd.uv_fs.loop, &stat_handle, fd.uv_fs.result, NULL)

    if stat_handle.result < 0:
        msg = uv_strerror(stat_handle.result).decode()
        raise IOError(stat_handle.result, msg)

    statbuf = <object> stat_handle.statbuf

    return os.stat_result((
        statbuf['st_mode'],
        statbuf['st_ino'],
        statbuf['st_dev'],
        statbuf['st_nlink'],
        statbuf['st_uid'],
        statbuf['st_gid'],
        statbuf['st_size'],
        statbuf['st_atim']['tv_sec'],
        statbuf['st_mtim']['tv_sec'],
        statbuf['st_ctim']['tv_sec']
    ))

open = AsyncFile

