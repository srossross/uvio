from libc.stdint cimport uint64_t, int64_t

cdef extern from "uv.h":

    ctypedef enum uv_run_mode:
      UV_RUN_DEFAULT
      UV_RUN_ONCE
      UV_RUN_NOWAIT

    ctypedef struct uv_loop_t:
      void* data


    int uv_loop_init(uv_loop_t*)
    int uv_loop_close(uv_loop_t*)
    uv_loop_t* uv_default_loop()

    int uv_run(uv_loop_t*, uv_run_mode) nogil
    void uv_stop(uv_loop_t*)

    int uv_loop_alive(uv_loop_t*)

    ctypedef struct uv_req_t:
        void* data
        uv_req_type type

    void uv_fs_req_cleanup(uv_fs_t* req)

    ctypedef struct uv_handle_t:
      void* data
      uv_loop_t * loop

    ctypedef void (*uv_walk_cb)(uv_handle_t* handle, void* arg)
    void uv_walk(uv_loop_t* loop, uv_walk_cb walk_cb, void* arg)

    ctypedef void (*uv_close_cb)(uv_handle_t* handle)

    int uv_is_active(uv_handle_t*)
    int uv_is_closing(uv_handle_t*)
    int uv_close(uv_handle_t*, uv_close_cb)
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

    ctypedef enum uv_req_type:
      UV_REQ
      UV_CONNECT
      UV_WRITE

      UV_SHUTDOWN
      UV_UDP_SEND
      UV_FS
      UV_WORK
      UV_GETADDRINFO
      UV_GETNAMEINFO

    ctypedef struct uv_timespec_t:
      long tv_sec
      long tv_nsec


    enum: UV_EOF


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
    int uv_fs_write(uv_loop_t* loop, uv_fs_t* req, uv_file file, const uv_buf_t bufs[], unsigned int nbufs, int64_t offset, uv_fs_cb cb)

    int uv_fs_fstat(uv_loop_t*, uv_fs_t*, uv_file, uv_fs_cb)

    const char* uv_strerror(int)



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

    enum: S_IRWXU
    enum: S_IRWXG
    enum: S_IRWXO

    enum: S_IRUSR
    enum: S_IWUSR
    enum: S_IRGRP
    enum: S_IROTH


    ctypedef void (*uv_alloc_cb)(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf)
    ctypedef void (*uv_read_cb)(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf);

    ctypedef void (*uv_close_cb)(uv_handle_t* handle)

    ctypedef struct uv_stream_t:
        void* data;
        uv_loop_t* loop

        uv_alloc_cb alloc_cb
        uv_read_cb read_cb


    struct sockaddr_in:
        pass

    struct sockaddr_in6:
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
    int uv_accept(uv_stream_t* server, uv_stream_t* client);

    ctypedef struct uv_connect_t:
        void* data;
        uv_stream_t* handle

    ctypedef void (*uv_connect_cb)(uv_connect_t* req, int status)

    int uv_tcp_connect(uv_connect_t* req, uv_tcp_t* handle, const sockaddr* addr, uv_connect_cb cb)


    int uv_is_readable(const uv_stream_t* handle)
    int uv_is_writable(const uv_stream_t* handle)

    ctypedef struct uv_write_t:
        void* data;

        uv_stream_t* send_handle;
        uv_stream_t* handle;

    ctypedef struct uv_shutdown_t:
      void* data
      uv_stream_t* handle


    ctypedef void (*uv_write_cb)(uv_write_t* req, int status)

    int uv_write(uv_write_t* req,
                uv_stream_t* handle,
                const uv_buf_t bufs[],
                unsigned int nbufs,
                uv_write_cb cb)



    int uv_read_start(uv_stream_t*,
                            uv_alloc_cb alloc_cb,
                            uv_read_cb read_cb)
    int uv_read_stop(uv_stream_t*)

    ctypedef void (*uv_shutdown_cb)(uv_shutdown_t* req, int status);

    int uv_shutdown(uv_shutdown_t* req,
                    uv_stream_t* handle,
                    uv_shutdown_cb cb);


    ctypedef struct uv_process_t:
      void *data
      uv_loop_t* loop
      int pid


    ctypedef struct uv_getaddrinfo_t:
        void *data
        uv_loop_t* loop;

    ctypedef struct uv_pipe_t:
      void *data
      uv_loop_t* loop

    int uv_pipe_init(uv_loop_t*, uv_pipe_t* handle, int ipc);
    int uv_pipe_open(uv_pipe_t*, uv_file file);
    int uv_pipe_bind(uv_pipe_t* handle, const char* name);
    void uv_pipe_connect(uv_connect_t* req, uv_pipe_t* handle, const char* name, uv_connect_cb cb)

    int uv_pipe_getsockname(const uv_pipe_t* handle,
                                    char* buffer,
                                    size_t* size);
    int uv_pipe_getpeername(const uv_pipe_t* handle,
                            char* buffer,
                            size_t* size);

    union uv_any_handle:
    # XX(ASYNC, async)
    # XX(CHECK, check)
    # XX(FS_EVENT, fs_event)
    # XX(FS_POLL, fs_poll)
      uv_handle_t handle
      uv_idle_t idle
      uv_pipe_t pipe
    # XX(NAMED_PIPE, pipe)
    # XX(POLL, poll)
    # XX(PREPARE, prepare)
      uv_process_t process
      uv_stream_t stream
      uv_tcp_t tcp
      uv_timer_t timer
    # XX(TTY, tty)
    # XX(UDP, udp)
    # XX(SIGNAL, signal)

    union uv_any_req:
      uv_req_t req
      uv_connect_t connect
      uv_write_t write
      uv_shutdown_t shutdown
      uv_work_t work

      # XX(UDP_SEND, udp_send)
      uv_fs_t fs
      # XX(WORK, work)

      uv_getaddrinfo_t getaddrinfo
      # XX(GETNAMEINFO, getnameinfo)

    ctypedef enum uv_stdio_flags:
      UV_IGNORE
      UV_CREATE_PIPE
      UV_INHERIT_FD
      UV_INHERIT_STREAM
      UV_READABLE_PIPE
      UV_WRITABLE_PIPE

    union uv_stdio_container_data:
      uv_stream_t* stream
      int fd

    ctypedef struct uv_stdio_container_t:
      uv_stdio_flags flags
      uv_stdio_container_data data


    ctypedef void (*uv_exit_cb)(uv_process_t*, int64_t exit_status, int term_signal)

    ctypedef int uv_uid_t
    ctypedef int uv_gid_t

    ctypedef struct uv_process_options_t:
      uv_exit_cb exit_cb
      const char* file
      char** args
      char** env
      const char* cwd
      unsigned int flags
      int stdio_count
      uv_stdio_container_t* stdio
      uv_uid_t uid
      uv_gid_t gid

    int uv_spawn(uv_loop_t* loop, uv_process_t* handle, const uv_process_options_t* options)
    int uv_process_kill(uv_process_t* handle, int signum)

    ctypedef int socklen_t

    cdef struct addrinfo:
      int ai_flags
      int ai_family
      int ai_socktype
      int ai_protocol
      socklen_t ai_addrlen
      sockaddr *ai_addr
      char *ai_canonname
      addrinfo* ai_next



    ctypedef void (*uv_getaddrinfo_cb)(uv_getaddrinfo_t* req, int status,  addrinfo* res)

    int uv_getaddrinfo(
        uv_loop_t* loop,
        uv_getaddrinfo_t* req,
        uv_getaddrinfo_cb getaddrinfo_cb,
        const char* node,
        const char* service,
        const addrinfo* hints
    )


    enum: PF_INET
    enum: SOCK_STREAM
    enum: IPPROTO_TCP

    int uv_ip4_name(const sockaddr_in* src, char* dst, size_t size);
    int uv_ip6_name(const sockaddr_in6* src, char* dst, size_t size);

    int uv_cancel(uv_req_t* req)

