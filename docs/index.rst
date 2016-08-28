.. uvio documentation master file, created by
   sphinx-quickstart on Sun Mar 20 17:54:35 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to uvio!
================================

This module provides infrastructure for writing single-threaded concurrent code using coroutines, multiplexing I/O access over sockets and other resources, running network clients and servers, named pipes, threadding, subprocesses and more. uvio is based off of `libuv <http://docs.libuv.org/>`_


This is a complete replacement for python's `asyncio <https://docs.python.org/3.4/library/asyncio.html>`_ module.

Motivation
--------------------------

 * Because I can
 * Provide async filesystem objects
 * Better subprocess support

Kitchen Sink
------------

.. highlight:: python

Example::

   import uvio

   @uvio.sync
   async def main():


   if __name__ == '__main__':
      main()

Why not AsyncIO?
----------------

 * We don't need to care about the event loop. In asyncio, the event loop is very prominent.
   A user does not need to care about the type of event loop they are using
 * Don't need to pass loop to every function. In many of the `examples <https://docs.python.org/3/library/asyncio-task.html#example-coroutine-displaying-the-current-date>` in asyncio this is the case.
 * handles keep loop running don't need to run_forever or run

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
   src/workers
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

