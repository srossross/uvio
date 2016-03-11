
from uv cimport *

cdef class Request:
    cdef uv_req_t* req

