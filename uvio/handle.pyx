
cdef class Handle:

    property loop:
        def __get__(self):
            if <int> self.handle.handle.loop:
                return <object> self.handle.handle.loop.data

    property _cpointer:
        def __get__(self):
            return <int> &self.handle


    def is_active(self):
        """Returns true if the handle is active, false if it’s inactive.
        What “active” means depends on the type of handle:

        Rule of thumb: if a handle of type uv_foo_t has a uv_foo_start() function,
        then it’s active from the moment that function is called. Likewise, uv_foo_stop()
        deactivates the handle again.
        """

        return bool(uv_is_active(&self.handle.handle))

    def close(self):
        if self.closing():
            raise RuntimeError("Can not close handle. it is already closed or closing")

        uv_close(&self.handle.handle, NULL);

    def closing(self):
        "Returns true if the handle is closing or closed, false otherwise"
        return bool(uv_is_closing(&self.handle.handle))

    def ref(self):
        uv_ref(&self.handle.handle)

    def unref(self):
        uv_unref(&self.handle.handle)

    def has_ref(self):
        return bool(uv_has_ref(&self.handle.handle))
