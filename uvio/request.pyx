from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

cdef class Request:
    def __cinit__(self):
        self.req.req.data = NULL

    def is_active(self):
        return self.req.req.data != NULL

    def _set_active(self):
        self.req.req.data = <void*><object> self
        Py_INCREF(self)

    def _set_unactive(self):
        self.req.req.data = NULL
        Py_DECREF(self)

