"""
libuv file system operations
"""
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

cdef void fs_callback(uv_fs_t* _req) with gil:
    if _req.data:
        req = <object> _req.data
        req.completed()

class FileHandle(Request):

    @property
    def uv_fileno(Request self):
        return self.req.fs.result

    @property
    def loop(Request self):
        if self.req.fs.loop and self.req.fs.loop.data:
            return <object> self.req.fs.loop.data

    def __del__(Request self):
        uv_fs_req_cleanup(&self.req.fs)


class Write(FileHandle, Future):

    def __init__(Request self, uv_file, bytes data):
        self.uv_file = uv_file
        self.data = data
        self._result = len(data)

        self.req.req.data = <void*> self


        cdef uv_buf_t bufs = uv_buf_init(self.data, len(self.data))

        cdef Loop loop = uv_file.loop

        failure = uv_fs_write(
            loop.uv_loop, &self.req.fs, self.uv_file.uv_fileno,
            &bufs, 1, -1, fs_callback)

        if failure < 0:
            msg = uv_strerror(failure).decode()
            raise IOError(failure, msg)


class Read(FileHandle, Future):


    def __init__(Request self, uv_file, n):
        self.uv_file = uv_file
        self.n = n
        self.buf = bytearray(n)

        self.req.req.data = <void*> self

        cdef uv_buf_t bufs = uv_buf_init(self.buf, self.n)

        cdef Loop loop = uv_file.loop

        uv_fs_read(
            loop.uv_loop, &self.req.fs, self.uv_file.uv_fileno,
            &bufs, 1, -1, fs_callback
        )

    def result(self):
        if self.uv_fileno > 0:
            return self.buf[:self.uv_fileno]
        else:
            return b''





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

    def __uv_init__(Request self, Loop loop):

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


        self.req.req.data = <void*> self

        uv_fs_open(
            loop.uv_loop,
            &self.req.fs,
            self.filename.encode(), flags, mode, fs_callback
        )

    def __uv_complete__(self):
        self.uv_fileno

        self._done = True
        if self.uv_fileno < 0:
            self._exception = IOError(self.uv_fileno, uv_python_strerror(self.uv_fileno))
            return

    async def __aenter__(self):
        return await self

    async def __aexit__(self, *args):
        self.close()

    def close(Request self):
        'Close the file'
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
        '''
        Read from underlying buffer until we have n characters or we hit EOF.
        If n is negative or omitted, read until EOF.

        the read must be awaited e.g.::

            async with uvio.fd.open('data.txt') as fd:
                data = await fd.read()
        '''
        if n <= 0:
            n = self._size()

        return Read(self, n)

    def write(Request self, data):
        '''Write string to stream.
        Returns the number of characters written (which is always equal to
        the length of the string).

        awaiting a write is optional e.g.::

            async with uvio.fd.open('data.txt', 'w') as fd:
                n = await fd.write(b'some bytes')
                fd.write(b'some more bytes')

        '''

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

def open(filename, mode='r'):
    """
    Open a file
    """
    return AsyncFile(filename, mode=mode)

