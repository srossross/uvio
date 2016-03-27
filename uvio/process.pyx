from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .uv cimport *
from ._loop cimport Loop
from .handle cimport Handle


import os
import sys
import inspect
import signal

from .futures import Future
from .pipes import Pipe

IGNORE = UV_IGNORE
PIPE = UV_CREATE_PIPE
INHERIT_FD = UV_INHERIT_FD
INHERIT_STREAM = UV_INHERIT_STREAM
READABLE = UV_READABLE_PIPE
WRITABLE = UV_WRITABLE_PIPE

cdef void exit_callback(uv_process_t* _handle, int64_t exit_status, int term_signal) with gil:

    returncode = <object> _handle.data

    try:
        returncode.__uv_complete__(exit_status, term_signal)
    except BaseException as err:
        returncode.loop.catch(err)
    else:
        returncode.loop.completed(returncode)


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

        self.opts.exit_cb = exit_callback

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
        self._result = None
        self._term_signal = None

    def __repr__(self):
        return "<{} exit_status={} term_signal={}>".format(
            type(self).__qualname__,
            self.exit_status,
            self.term_signal,
        )
    @property
    def loop(self):
        return self.process.loop

    @property
    def exit_status(self):
        return self._result

    @property
    def term_signal(self):
        return self._term_signal

    def start(self, loop):
        pass


    def __uv_complete__(self, exit_status, term_signal):
        self._result = exit_status
        self._done = True
        self._term_signal = term_signal

        cdef ProcessOptions options = self.process.options

        for i in range(3):

            if options.opts.stdio[i].flags & UV_CREATE_PIPE:
                pipe = <object> options.opts.stdio[i].data.stream.data
                if not pipe.closing():
                    pipe.close()
                    self.loop.completed(pipe)


class Popen(Handle, Future):
    '''Popen(stdin=None, stdout=None, stderr=None)

    Execute a child program in a new process.

    :param args: args should be a sequence of program arguments.

    '''
    def __init__(self, args, stdin=None, stdout=None, stderr=None, **kwargs):

        if stdin == PIPE:
            stdin = Pipe()
        elif stdin is None:
            stdin = sys.stdin

        if stdout == PIPE:
            stdout = Pipe()
        elif stdout is None:
            stdout = sys.stdout

        if stderr == PIPE:
            stderr = Pipe()
        elif stderr is None:
            stderr = sys.stderr

        self.options = ProcessOptions(args, stdin=stdin, stdout=stdout, stderr=stderr, **kwargs)
        self._returncode = None

    def result(self):
        return self

    def kill(Handle self, int signum=signal.SIGKILL):
        """kill(signum=signal.SIGKILL)

        Kill this process
        """
        failure = uv_process_kill(&self.handle.process, signum)

        if failure:
            msg = <char*> uv_strerror(failure)
            raise RuntimeError(failure, "Could not kill process: {}".format(msg.decode()))

    def __uv_init__(Handle self, Loop loop):

        self._returncode = ReturnCode(self)

        self.handle.handle.data = <void*> <object> self._returncode
        Py_INCREF(self._returncode)

        cdef ProcessOptions options = self.options
        cdef int i

        for i in range(3):
            if options.opts.stdio[i].flags & UV_CREATE_PIPE:
                pipe = <object> options.opts.stdio[i].data.stream.data
                pipe.__uv_init__(loop)


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

        # This is awaited just to get the loop
        # To await the exit users can do `await popen.returncode`
        self._done = True
        self.completed()

    @property
    def stdout(self):
        '''If the stdout argument was PIPE,
        this attribute is a :class:`Pipe` object that provides input to the child process. Otherwise, it is None.
        '''

        return self.options.stdout

    @property
    def stdin(self):
        '''If the stdin argument was PIPE,
        this attribute is a :class:`Pipe` object that provides input to the child process. Otherwise, it is None.
        '''

        return self.options.stdin

    @property
    def stderr(self):
        '''If the stderr argument was PIPE,
        this attribute is a :class:`Pipe` object that provides input to the child process. Otherwise, it is None.
        '''
        return self.options.stderr

    @property
    def returncode(self):
        '''
        this property returns an awaitable coroutine::

            returncode = await process.returncode
        '''

        return self._returncode

    @property
    def pid(Handle self):
        'The pid of the child process'
        return self.handle.process.pid


