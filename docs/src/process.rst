Subprocess
=======================

Subprocess examples
-------------------

Example of a subprocess protocol using to get the output of a subprocess and to wait for the subprocess exit. The subprocess is created by the uvio.subprocess.Popen method::

    import uvio
    import sys

    @uvio.sync(timout=10)
    async def get_date():
        code = 'import datetime; print(datetime.datetime.now())'

        # Create the subprocess controlled by the protocol DateProtocol,
        # redirect the standard output into a pipe

        process = await uvio.process.Popen(
           [sys.executable, '-c', code],
            stdin=None, stderr=None, stdout=uvio.process.PIPE
        )


        # Pipe output into byte stream
        line = await process.stdout.readline()


        # Wait for the subprocess exit using the process_exited() method
        # of the protocol
        print('Exit Status', await process.returncode)

        # Read the output which was collected by the pipe_data_received()
        # method of the protocol
        data = output.getvalue()
        return data.decode('ascii').rstrip()

    print("Current date: %s" % get_date())





