
from uv cimport *

cdef class Handle:
    cdef uv_handle_t* uv_handle


