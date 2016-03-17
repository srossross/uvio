from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from .loop cimport Loop, uv_python_callback

from .loop cimport Loop
from .handle cimport Handle


import os
import inspect
import signal

from .futures import Future
from .stream import Pipe

IGNORE = UV_IGNORE
PIPE = UV_CREATE_PIPE
INHERIT_FD = UV_INHERIT_FD
INHERIT_STREAM = UV_INHERIT_STREAM
READABLE = UV_READABLE_PIPE
WRITABLE = UV_WRITABLE_PIPE

cdef void uv_python_exit_cb(uv_process_t* uv_process, int64_t exit_status, int term_signal) with gil:

    returncode = <object> uv_process.data

    returncode._term_signal = term_signal
    returncode._result = exit_status

    try:
        returncode.set_completed()
    except BaseException as err:
        loop = <object> uv_process.loop.data
        loop.catch(err)


    Py_DECREF(returncode)
    uv_process.data = NULL


cdef char* copy_py_str(py_str):

    cdef bytes py_bytes = py_str.encode()
    cdef int size = len(py_bytes)
    cdef char* result = <char*> malloc(sizeof(char) * (size + 1))

    memcpy(result, <const char*> py_bytes, size)
    result[size] = 0
    return result


cdef char** copy_list_of_strings(args):
    cdef char** result = <char**> malloc(sizeof(char*) * (len(args)+1))
    for i, item in enumerate(args):
        result[i] = copy_py_str(args[i])

    result[len(args)] = NULL

    return result

cdef free_list_of_strings(char** los):

    cdef i = 0

    while los[i] != NULL:
        free(los[i])
        i += 1

    return


cdef get_stdio(uv_stdio_container_t* stdio, int i):

    if stdio[i].flags == UV_IGNORE:
        return None
    elif stdio[i].flags & UV_CREATE_PIPE:
        pipe = <object> stdio[i].data.stream.data
        return pipe
    elif stdio[i].flags == UV_INHERIT_FD:
        return None
    else:
        raise Exception("unknown flags for stdio")


cdef set_stdio(uv_stdio_container_t* stdio, i, io, read=False):

    cdef Handle apipe

    if io is None or io == UV_IGNORE:
        stdio[i].flags = UV_IGNORE

    elif isinstance(io, Pipe):

        apipe = io
        if read:
            stdio[i].flags = <uv_stdio_flags> (UV_CREATE_PIPE | UV_READABLE_PIPE)
        else:
            stdio[i].flags = <uv_stdio_flags> (UV_CREATE_PIPE | UV_WRITABLE_PIPE)

        stdio[i].data.stream = &apipe.handle.stream
        stdio[i].data.stream.data = <void*> <object> apipe

        Py_INCREF(apipe)

    elif hasattr(io, 'fileno'):
        stdio[i].flags = UV_INHERIT_FD
        stdio[i].data.fd = io.fileno()

    else:
        raise TypeError("don't know how to handle stdio type {}".format(io))



cdef class ProcessOptions:

    cdef uv_process_options_t opts

    def __init__(self, args, cwd=None, stdin=None, stdout=None, stderr=None, env=None):

        self.opts.exit_cb = uv_python_exit_cb

        self.opts.file = copy_py_str(args[0])

        self.opts.args = copy_list_of_strings(args)

        if env:
            env_list = ["{}={}".format(key,value) for key,value in env.items()]
            self.opts.env = copy_list_of_strings(env_list)

        if cwd:
            self.opts.cwd = copy_py_str(cwd)

        self.opts.stdio_count = 3
        self.opts.stdio = <uv_stdio_container_t*> malloc(sizeof(uv_stdio_container_t) * 3)


        set_stdio(self.opts.stdio, 0, stdin, read=True)


        set_stdio(self.opts.stdio, 1, stdout)
        set_stdio(self.opts.stdio, 2, stderr)



    def __dealloc__(self):

        cdef int i = 0

        if self.opts.file:
            free(<void*>self.opts.file)
            self.opts.file = NULL

        if self.opts.args:
            free_list_of_strings(self.opts.args)
            free(self.opts.args)
            self.opts.args = NULL

        if self.opts.env:
            free_list_of_strings(self.opts.env)
            free(self.opts.env)
            self.opts.env = NULL

        if self.opts.cwd:
            free(<void*>self.opts.cwd)
            self.opts.cwd = NULL




    property cwd:
        def __get__(self):
            return self.opts.cwd.decode()

    property executable:
        def __get__(self):
            return self.opts.file.decode()

    property args:
        def __get__(self):
            cdef int i = 0
            result = []
            while 1:
                if self.opts.args[i] == NULL:
                    break
                result.append(self.opts.args[i].decode())
                i+=1

            return result

    property stdin:
        def __get__(self):
            return get_stdio(self.opts.stdio, 0)

    property stdout:
        def __get__(self):
            return get_stdio(self.opts.stdio, 1)

    property stderr:
        def __get__(self):
            return get_stdio(self.opts.stdio, 2)


class ReturnCode(Future):
    def __init__(self, process):
        self.process = process
        self._is_active = False

    def is_active(self):
        return self._is_active

    def __uv_start__(self, loop):
        self._is_active = True
        self.loop = loop

class Popen(Handle, Future):

    def __init__(self, args, stdin=None, stdout=None, stderr=None, **kwargs):

        if stdin == PIPE:
            stdin = Pipe()

        if stdout == PIPE:
            stdout = Pipe()

        if stderr == PIPE:
            stderr = Pipe()

        self.options = ProcessOptions(args, stdin=stdin, stdout=stdout, stderr=stderr, **kwargs)
        self._returncode = None

    def result(self):
        return self

    def kill(Handle self, int signum=signal.SIGKILL):

        failure = uv_process_kill(&self.handle.process, signum)

        if failure:
            msg = <char*> uv_strerror(failure)
            raise RuntimeError(failure, "Could not kill process: {}".format(msg.decode()))

    def __uv_start__(Handle self, Loop loop):

        self._returncode = ReturnCode(self)

        self.handle.handle.data = <void*> <object> self._returncode
        Py_INCREF(self._returncode)

        cdef ProcessOptions options = self.options
        cdef int i

        for i in range(3):
            if options.opts.stdio[i].flags & UV_CREATE_PIPE:
                pipe = <object> options.opts.stdio[i].data.stream.data
                pipe.start(loop)

        failure = uv_spawn(
            loop.uv_loop,
            &self.handle.process,
            &options.opts
        )

        if failure:
            msg = <char*> uv_strerror(failure)
            raise RuntimeError(failure, "Could not spawn process: {}".format(msg.decode()))

        # TODO: document this. this is just to set up the loop IO
        # There is not really an async operation here
        # we need to use the await tho to get the 'loop' object for initialization

        for i in range(0, 3):
            if options.opts.stdio[i].flags & UV_CREATE_PIPE:
                pipe = <object> options.opts.stdio[i].data.stream.data
                if pipe.readable():
                    pipe.resume()

        self.set_completed()


    @property
    def stdout(self):
        return self.options.stdout

    @property
    def stdin(self):
        return self.options.stdin

    @property
    def stderr(self):
        return self.options.stderr

    @property
    def returncode(self):
        return self._returncode

