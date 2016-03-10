from libc.stdint cimport uint64_t, int64_t

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

    void uv_run(uv_loop_t*, uv_run_mode) nogil
    void uv_stop(uv_loop_t*)

    int uv_loop_alive(uv_loop_t*)


    ctypedef struct uv_handle_t:
      void* data
      uv_loop_t * loop

    int uv_is_active(uv_handle_t*)
    int uv_is_closing(uv_handle_t*)
    int uv_close(uv_handle_t*)
    void uv_ref(uv_handle_t*)
    void uv_unref(uv_handle_t*)
    int uv_has_ref(uv_handle_t*)




    ctypedef struct uv_idle_t:
        void* data
        uv_loop_t * loop

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

    enum uv_req_type:
      UV_REQ

    ctypedef struct uv_timespec_t:
      long tv_sec
      long tv_nsec


    ctypedef struct uv_stat_t:
      uint64_t st_dev
      uint64_t st_mode
      uint64_t st_nlink
      uint64_t st_uid
      uint64_t st_gid
      uint64_t st_rdev
      uint64_t st_ino
      uint64_t st_size
      uint64_t st_blksize
      uint64_t st_blocks
      uint64_t st_flags
      uint64_t st_gen
      uv_timespec_t st_atim
      uv_timespec_t st_mtim
      uv_timespec_t st_ctim
      uv_timespec_t st_birthtim

    enum uv_fs_type:
      # UV_FS_UNKNOWN = -1,
      UV_FS_CUSTOM
      UV_FS_OPEN
      UV_FS_CLOSE
      UV_FS_READ
      UV_FS_WRITE
      # UV_FS_SENDFILE,
      # UV_FS_STAT,
      # UV_FS_LSTAT,
      # UV_FS_FSTAT,
      # UV_FS_FTRUNCATE,
      # UV_FS_UTIME,
      # UV_FS_FUTIME,
      # UV_FS_ACCESS,
      # UV_FS_CHMOD,
      # UV_FS_FCHMOD,
      # UV_FS_FSYNC,
      # UV_FS_FDATASYNC,
      # UV_FS_UNLINK,
      # UV_FS_RMDIR,
      # UV_FS_MKDIR,
      # UV_FS_MKDTEMP,
      # UV_FS_RENAME,
      # UV_FS_SCANDIR,
      # UV_FS_LINK,
      # UV_FS_SYMLINK,
      # UV_FS_READLINK,
      # UV_FS_CHOWN,
      # UV_FS_FCHOWN,
      # UV_FS_REALPATH


    ctypedef struct uv_fs_t:

        void* data
        # read-only
        uv_req_type type


        uv_fs_type fs_type
        uv_loop_t* loop
        #uv_fs_cb cb
        ssize_t result
        const char* path

        uv_stat_t statbuf

    ctypedef void (*uv_fs_cb)(uv_fs_t* handle)


    int uv_fs_open(uv_loop_t*, uv_fs_t*, char*, int flags, int mode, uv_fs_cb cb)
    int uv_fs_close(uv_loop_t*, uv_fs_t*, uv_file, uv_fs_cb)

    int uv_fs_read(uv_loop_t*, uv_fs_t* req, uv_file file, uv_buf_t bufs[], unsigned int, int64_t offset, uv_fs_cb cb)

    int uv_fs_fstat(uv_loop_t*, uv_fs_t*, uv_file, uv_fs_cb)

    char* uv_strerror(int)



    ctypedef struct uv_work_t:
        void* data;
        uv_loop_t* loop

    ctypedef void (*uv_work_cb)(uv_work_t* req)
    ctypedef void (*uv_after_work_cb)(uv_work_t* req, int status)

    int uv_queue_work(uv_loop_t* loop, uv_work_t* req, uv_work_cb work_cb, uv_after_work_cb after_work_cb)

    enum: O_CREAT
    enum: O_EXCL
    enum: O_NOCTTY
    enum: O_TRUNC

    enum: O_APPEND
    enum: O_DSYNC
    enum: O_NONBLOCK
    enum: O_RSYNC
    enum: O_SYNC

    enum: O_ACCMODE # O_RDONLY|O_WRONLY|O_RDWR

    enum: O_RDONLY
    enum: O_WRONLY
    enum: O_RDWR



    ctypedef struct uv_stream_t:
        void* data;
        uv_loop_t* loop

    struct sockaddr_in:
        pass

    ctypedef struct uv_tcp_t:
        void* data;
        uv_loop_t* loop

    struct sockaddr
    ctypedef void (*uv_connection_cb)(uv_stream_t* server, int status);

    int uv_ip4_addr(char* ip, int port, sockaddr_in* addr)
    int uv_tcp_init(uv_loop_t*, uv_tcp_t* handle);
    int uv_tcp_bind(uv_tcp_t* handle, const sockaddr* addr, unsigned int flags);

    int uv_listen(uv_stream_t* stream, int backlog, uv_connection_cb cb);


    ctypedef struct uv_connect_t:
        void* data;
        uv_loop_t* loop
        uv_stream_t* handle

    ctypedef void (*uv_connect_cb)(uv_connect_t* req, int status)

    int uv_tcp_connect(uv_connect_t* req, uv_tcp_t* handle, const sockaddr* addr, uv_connect_cb cb)



