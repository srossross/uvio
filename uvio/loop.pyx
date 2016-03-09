from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from uv cimport *


cdef void uv_python_callback(uv_handle_t* handle):

    callback = <object> handle.data
    callback()
    Py_DECREF(callback)

cdef class Loop:

    # def next_tick(self, callback):
    #     idle = Idle(self)
    #     idle.start(callback)
    #     return idle

    # def set_timeout(self, callback, int timeout, repeat=False):
    #     py_timer = Timer(self, timeout, repeat)
    #     py_timer.start(callback)
    #     return py_timer

    def run(self):
        uv_run(self.uv_loop, UV_RUN_DEFAULT)

    def close(self):
        uv_loop_close(self.uv_loop)

    async def sleep(self, miliseconds):
        pass

    # def alive(self):
    #     return bool(uv_loop_alive(self.uv_loop))

    # def stop(self):
    #     uv_loop_stop(self.uv_loop)

    @classmethod
    def get_default_loop(cls):
        cdef Loop loop = Loop()
        loop.uv_loop = uv_default_loop()
        return loop
