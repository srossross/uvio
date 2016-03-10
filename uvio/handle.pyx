
cdef class Handle:

    property loop:
        def __get__(self):
            if <int> self.uv_handle:
                return <object> self.uv_handle.loop.data

    def __cinit__(self, *args, **kwargs):
        self.uv_handle = NULL

    property _cpointer:
        def __get__(self):
            return <int> self.uv_handle


    def is_active(self):
        """Returns true if the handle is active, false if it’s inactive.
        What “active” means depends on the type of handle:

        Rule of thumb: if a handle of type uv_foo_t has a uv_foo_start() function,
        then it’s active from the moment that function is called. Likewise, uv_foo_stop()
        deactivates the handle again.
        """

        return bool(<int>self.uv_handle) and bool(uv_is_active(self.uv_handle))

    def is_closing(self):
        "Returns true if the handle is closing or closed, false otherwise"
        return bool(uv_is_closing(self.uv_handle))

    def ref(self):
        if not self.uv_handle:
            raise Exception("handle has not be started yet")
        uv_ref(self.uv_handle)

    def unref(self):
        if not self.uv_handle:
            raise Exception("handle has not be started yet")

        uv_unref(self.uv_handle)

    def has_ref(self):

        if not self.uv_handle:
            return False

        return bool(uv_has_ref(self.uv_handle))
