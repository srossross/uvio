
from uv cimport *

cdef void uv_python_callback(uv_handle_t* handle)

cdef class Loop:
    cdef uv_loop_t* uv_loop

