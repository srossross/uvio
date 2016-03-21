.. uvio documentation master file, created by
   sphinx-quickstart on Sun Mar 20 17:54:35 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

The UV Event Loop
=================


Event loop examples
-------------------


Hello World with next_tick()
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Example using the :meth:`Loop.next_tick` method to schedule a
callback. The callback displays ``"Hello World"`` and then stops the event
loop::

    import uvio

    def hello_world(loop):
        print('Hello World')

    loop = uvio.get_default_loop()

    # Schedule a call to hello_world()
    loop.next_tick(hello_world, loop)

    # Blocking call interrupted by loop.stop()
    loop.run()
    loop.close()


Display the current date with schedule()
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Example of callback displaying the current date every second. The callback uses the BaseEventLoop.call_later() method to reschedule itself during 5 seconds, and then stops the event loop::

    import uvio
    import datetime

    async def display_date(end_time):
        print(datetime.datetime.now())

        if (datetime.datetime.now() + 1.0) < end_time:
            await schedule(1, display_date, end_time)



    loop = uvio.get_default_loop()

    # Schedule the first call to display_date()
    end_time = datetime.datetime.now() + 5.0
    loop.next_tick(display_date, end_time)

    # Blocking call will exit when all tasks are finished
    loop.run()
    loop.close()

