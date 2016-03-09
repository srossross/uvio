
cdef extern from "uv.h":

    cdef  enum uv_run_mode:
      UV_RUN_DEFAULT,
      UV_RUN_ONCE,
      UV_RUN_NOWAIT

    ctypedef struct uv_loop_t:
      void* data

    int uv_loop_init(uv_loop_t*)
    int uv_loop_close(uv_loop_t*)
    uv_loop_t* uv_default_loop()
    void uv_run(uv_loop_t*, uv_run_mode)
    int uv_loop_alive(uv_loop_t*)
    void uv_loop_stop(uv_loop_t*)

    ctypedef struct uv_handle_t:
      void* data
      uv_loop_t * loop

    ctypedef struct uv_idle_t:
        void* data

    ctypedef void (*uv_idle_cb)(uv_idle_t*)
    void uv_idle_stop(uv_idle_t*)
    void uv_idle_start(uv_idle_t*, uv_idle_cb)
    void uv_idle_stop(uv_idle_t*)
    void uv_idle_init(uv_loop_t*, uv_idle_t*)

    ctypedef struct uv_timer_t:
        void* data

    ctypedef void (*uv_timer_cb)(uv_timer_t* handle)

    int uv_timer_init(uv_loop_t*, uv_timer_t*)
    int uv_timer_start(uv_timer_t*, uv_timer_cb, int, int)
    int uv_timer_stop(uv_timer_t*)
    int uv_timer_again(uv_timer_t*)

    ctypedef struct uv_buf_t:
        char* base
        size_t len

    uv_buf_t uv_buf_init(char* base, int len)

    ctypedef ssize_t uv_file

    ctypedef struct uv_fs_t:
        void* data
        uv_file result


    ctypedef void (*uv_fs_cb)(uv_fs_t* handle)

    int uv_fs_open(uv_loop_t*, uv_fs_t*, char*, int flags, int mode, uv_fs_cb cb)
