
from uv cimport *

# cdef void uv_python_callback(uv_handle_t* handle) with gil


# cdef void idle_callback(uv_idle_t*) with gil
# cdef void listen_callback(uv_stream_t* server, int status) with gil;

cdef object uv_python_strerror(int code)

cdef class Loop:
    cdef uv_loop_t* uv_loop
    cdef uv_idle_t uv_tick

