.. uvio documentation master file, created by
   sphinx-quickstart on Sun Mar 20 17:54:35 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to uvio!
================================

This module provides infrastructure for writing single-threaded concurrent code using coroutines, multiplexing I/O access over sockets and other resources, running network clients and servers, named pipes, threadding, subprocesses and more. uvio is based off of `libuv <http://docs.libuv.org/>`_

.. image:: _static/logo.png
   :scale: 100 %
   :alt: libuv
   :align: center
   :target: http://docs.libuv.org/

This is a complete replacement for python's `asyncio <https://docs.python.org/3.4/library/asyncio.html>`_ module.


Features
--------

 * Full-featured event loop backed by epoll, kqueue, IOCP, event ports.
 * Asynchronous TCP and UDP sockets
 * Asynchronous DNS resolution
 * Asynchronous file and file system operations
 * IPC with socket sharing, using Unix domain sockets or named pipes (Windows)
 * Child processes
 * Thread pool
 * TODO: File system events
 * TODO: ANSI escape code controlled TTY
 * TODO: Signal handling
 * TODO: High resolution clock
 * TODO: Threading and synchronization primitives

Contents:

.. toctree::
   :maxdepth: 2

   src/event_loop
   src/coroutines
   src/process
   src/fs
   src/net
   src/pipes
   src/api



Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

