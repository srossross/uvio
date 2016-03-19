from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

req_type_map = {
  UV_REQ: 'req',
  UV_CONNECT: 'connect',
  UV_WRITE: 'write',

  UV_SHUTDOWN: 'shutdown',
  UV_UDP_SEND: 'udp_send',
  UV_FS: 'fs',
  UV_WORK: 'work',
  UV_GETADDRINFO: 'getaddrinfo',
  UV_GETNAMEINFO: 'getnameinfo',                                              \

}

cdef class Request:
    def __cinit__(self):
        self.req.req.data = NULL

    def __dealloc__(self):
        self.req.req.data = NULL
        uv_fs_req_cleanup(&self.req.fs)


    def __uv_init__(self, loop):
      pass

    def start(self, loop):

        if not self.req.req.data:
            self.__uv_init__(loop)
            self.req.req.data = <void*> self

    property req_type:
        def __get__(self):
            return req_type_map.get(self.req.req.type)

    property loop:
        def __get__(self):
            cdef uv_loop_t* uv_loop
            req_type = self.req_type

            if req_type is None:
              return None

            if req_type == 'work':
                uv_loop = self.req.work.loop
            elif req_type == 'connect':
                uv_loop = self.req.connect.handle.loop
            elif req_type ==  'shutdown':
                uv_loop = self.req.shutdown.handle.loop
            elif req_type ==  'write':
                uv_loop = self.req.write.handle.loop
            else:
                raise AttributeError("request type '{}' does have attribute loop".format(req_type))

            if uv_loop == NULL:
                return None

            return <object> uv_loop.data

    def __uv_complete__(self, *args):
        self._done = True

    def completed(self, *args):
        try:
            self.__uv_complete__(*args)
        except BaseException as err:
            self.loop.catch(err)
        else:
            self.loop.completed(self)
