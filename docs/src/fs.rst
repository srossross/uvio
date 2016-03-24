File System
=======================


File System examples
---------------------


Reading Files
^^^^^^^^^^^^^

Open a file for reading and read the data:

.. code-block:: python

    async with uvopen(test_data, "r") as fd:
        data = await fd.read()

