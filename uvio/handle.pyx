
cdef class Handle:

    def __dealloc__(self):
        self.handle.handle.data = NULL

    property loop:
        def __get__(self):
            if <int> self.handle.handle.loop:
                return <object> self.handle.handle.loop.data
        def __set__(self, value):
            loop = <object> self.handle.handle.loop.data
            assert loop is  value

    property _cpointer:
        def __get__(self):
            return <int> &self.handle


    def is_active(self):
        """Returns true if the handle is active, false if it’s inactive.
        What “active” means depends on the type of handle:

        """

        return bool(uv_is_active(&self.handle.handle))

    def close(self):
        if self.closing():
            raise RuntimeError("Can not close handle. it is already closed or closing")

        uv_close(&self.handle.handle, NULL);

        self.loop.completed(self)

    def closing(self):
        "Returns true if the handle is closing or closed, false otherwise"
        return bool(uv_is_closing(&self.handle.handle))

    def ref(self):
        '''ref()

        The libuv event loop (if run in the default mode) will run until there are no active and referenced handles left.
        The user can force the loop to exit early by unreferencing handles which are active,
        for example by calling handle.unref()

        A handle can be referenced or unreferenced,
        the refcounting scheme doesn’t use a counter, so both operations are idempotent.

        All handles are referenced when active by default, see :method:`Stream.active()` for a more
        detailed explanation on what being active involves.
        '''

        uv_ref(&self.handle.handle)

    def unref(self):
        '''unref()
        un ref the handle'''
        uv_unref(&self.handle.handle)

    def has_ref(self):
        return bool(uv_has_ref(&self.handle.handle))

    def start(self, loop):
        '''
        Activate this handle
        '''
        if not self.handle.handle.data:
            self.__uv_init__(loop)

        self.__uv_start__()

    def __uv_start__(self):
        return

    def __uv_complete__(self, *args):
        self._done = True

    def completed(self, *args):

        self.loop.completed(self)

        try:
            self.__uv_complete__(*args)
        except BaseException as err:
            self.loop.catch(err)




