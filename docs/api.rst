UVIO API refrence
=================

.. module:: uvio

The Event Loop
------------------

.. autoclass:: Loop
   :members: run, next_tick, set_timeout, alive, stop, close, walk, create, exceptions


The Stream Object
------------------

The stream object! This is the most used object in libuv

.. autoclass:: Stream
   :members:
   :inherited-members:


Coroutines
----------

.. autofunction:: sleep

.. autofunction:: get_current_loop

.. autofunction:: uvio.worker


.. module:: uvio.process

Subprocess Module
-----------------

.. autoclass:: Popen
   :members:


.. module:: uvio.net

Network Module
--------------

.. autofunction:: listen

.. autofunction:: connect

.. autofunction:: getaddrinfo

FS Module
--------------

.. module:: uvio.fs

.. autofunction:: open

.. autoclass:: AsyncFile
   :members:

.. module:: uvio.pipes

Pipes Module
--------------

.. autofunction:: listen

.. autofunction:: connect


