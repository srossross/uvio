.. uvio documentation master file, created by
   sphinx-quickstart on Sun Mar 20 17:54:35 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

The UV Event Loop
=================


Event loop examples
-------------------

Execute async fuctions with uvio.sync()
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Often you don't care about the event loop if that is
the case and you just want to get things done use the
:function:`uvio.sync` decorator::


    import uvio

    @uvio.sync
    async def main(args):
        await uvio.sleep(1)
        print("OK!")

    if __name__ == '__main__':
        main()





Display the current date with get_current_loop()
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

with asyncio, the loop parameter often needs to be a part of the function call args
with uvio use `get_current_loop` wich will return the loop running the current coroutine::

    import uvio

    @uvio.sync
    async def main(args):

        loop = await uvio.get_current_loop()
        print(loop)


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

