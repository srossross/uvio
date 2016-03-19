from libc.stdlib cimport malloc, free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from ._loop cimport Loop, uv_python_strerror
from .request cimport Request
from .handle cimport Handle

import os
import inspect

from .futures import Future
from .pipes import Pipe


class FileHandle(Request):

    def __del__(Request self):
        uv_fs_req_cleanup(&self.req.fs)

    @property
    def uv_fileno(Request self):
        return self.req.fs.result

    @property
    def loop(Request self):
        if self.req.fs.loop and self.req.fs.loop.data:
            return <object> self.req.fs.loop.data


cdef void uv_python_fs_callback(uv_fs_t* req) with gil:

    if req.result < 0:
        error = IOError(req.result, uv_python_strerror(req.result))
    else:
        error = None

    callback = <object> req.data

    try:
        callback.set_completed(error)
    except BaseException as err:
        loop = <object> req.loop.data
        loop.catch(err)

    Py_DECREF(callback)

class Write(FileHandle, Future):
    def __init__(self, fileobj, bytes data):
        self.fileobj = fileobj
        self.data = data

    def result(self):
        return

    def __uv_start__(Request self, Loop loop):

        self._is_active = True

        self.req.fs.data = <void*> (<PyObject*> self)
        Py_INCREF(self)


        cdef uv_buf_t bufs = uv_buf_init(self.data, len(self.data))

        failure = uv_fs_write(
            loop.uv_loop, &self.req.fs, self.fileobj.uv_fileno,
            &bufs, 1, -1, uv_python_fs_callback)

        if failure < 0:
            msg = uv_strerror(failure).decode()
            raise IOError(failure, msg)


class Read(FileHandle, Future):


    def __init__(self, fileno, n):
        self.fileno = fileno
        self.n = n
        self.buf = bytearray(n)
        self._is_active = False

    def result(self):
        print("uv_fileno", self.uv_fileno)
        if self.uv_fileno > 0:
            return self.buf[:self.uv_fileno]
        else:
            return b''

    def is_active(self):
        return self._is_active and not self._done

    def __uv_start__(Request self, Loop loop):

        self._is_active = True

        self.req.fs.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        cdef uv_buf_t bufs = uv_buf_init(self.buf, self.n)

        uv_fs_read(
            loop.uv_loop, &self.req.fs, self.fileno,
            &bufs, 1, -1, uv_python_fs_callback
        )



class AsyncFile(FileHandle, Future):
    """
    The mode can be 'r' (default), 'w', 'x' or 'a' for reading,
    """


    def __init__(self, filename, mode='r'):

        self.filename = filename
        self.mode = mode

        if not isinstance(mode, str):
            raise TypeError("{}() argument 2 must be str, not {}".format(
                type(self).__qualname__,
                type(mode).__qualname__
            ))

        if mode[0] not in ['r', 'w', 'a', 'x']:
            raise ValueError("Must have exactly one of create/read/write/append")

        if len(mode) > 1 and mode[1] != '+':
            raise ValueError("Invalid mode {}".format(mode[1]))

        if len(mode) > 2:
            raise ValueError("Invalid mode {}".format(mode))

    def result(self):
        return self

    def __uv_start__(Request self, Loop loop):

        cdef int flags = 0
        cdef int mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH


        cdef int readwrite = len(self.mode) > 1 and self.mode[1] == '+'

        if self.mode[0] == 'r':
            flags = O_RDWR if readwrite else O_RDONLY
        elif self.mode[0] == 'w':
            flags = O_RDWR if readwrite else O_WRONLY
            flags |= O_CREAT
        elif self.mode[0] == 'a':
            flags = O_RDWR | O_APPEND
        elif self.mod == 'x':
            flags = O_RDWR if readwrite else O_WRONLY
            flags |= O_CREAT | O_EXCL


        self.req.fs.data = <void*> (<PyObject*> self)
        Py_INCREF(self)

        uv_fs_open(
            loop.uv_loop,
            &self.req.fs,
            self.filename.encode(), flags, mode, uv_python_fs_callback
        )

    async def __aenter__(self):
        return await self

    async def __aexit__(self, *args):
        self.close()

    def close(Request self):

        cdef uv_fs_t close_handle

        uv_fs_close(
            self.req.fs.loop,
            &close_handle,
            self.req.fs.result,
            NULL
        )

    def _size(Request self):
        cdef uv_fs_t stat_handle
        uv_fs_fstat(self.req.fs.loop, &stat_handle, self.req.fs.result, NULL)
        if stat_handle.result < 0:
            msg = uv_strerror(stat_handle.result).decode()
            raise IOError(stat_handle.result, msg)

        return stat_handle.statbuf.st_size

    def read(Request self, n=-1):

        if n <= 0:
            n = self._size()

        return Read(self.req.fs.result, n)

    def write(Request self, data):


        return Write(self, data)

    async def stream(Request self):

        cdef Handle pipe = Pipe(self.loop)

        failure = uv_pipe_open(&pipe.handle.pipe, self.req.fs.result)

        if failure < 0:
            msg = uv_strerror(failure).decode()
            raise IOError(failure, msg)

        return pipe

async def stream(filename, mode):
    afile = await AsyncFile(filename, mode)
    stream = await afile.stream()
    stream.resume()
    return stream



def fstat(Request fd):

    cdef uv_fs_t stat_handle
    uv_fs_fstat(fd.req.fs.loop, &stat_handle, fd.req.fs.result, NULL)

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

