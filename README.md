# uvio

Alternative for python asyncio based on libuv.


Just like `asyncio`, this module provides infrastructure for writing single-threaded concurrent code using coroutines, multiplexing I/O access over sockets and other resources, running network clients and servers, and other related primitives.


## Installation

Install libuv. sorry no conda package yet

```
git clone https://github.com/srossross/uvio
python setup.py install
```

## Network

```
from uvio import run
from uvio.net import connect, listen

async def echo_server(server, socket):

    @socket.data
    def echo(buf):
        socket.write(b"echo: " + buf)

    socket.resume()


@run(timout=1)
async def main():

    server = await listen("127.0.0.1", 80, echo_server)

    client = await connect("127.0.0.1", 80)

    @client.data
    def msg(client, data):
        print("The server echoe me", data)

        server.close()
        client.close()


    await client.write(b"this is a test")


```

## File IO

```
from uvio import fs

async with fs.open('test_write.txt', 'w') as fd:
    n = await fd.write(b"Hello World")

```

## Subprocess

```
from uvio.subprocess import Popen, PIPE
echo = await Popen(['echo', 'hello world'], stdout=PIPE)

@echo.stdout.data
def output(buf):
    print("program output:", buf)

print('echo exited with status code', await echo.returncode)

```

### Pipe output from one process to another

```
from uvio.subprocess import Popen, PIPE
echo = await Popen(['echo', 'hello world'], stdout=PIPE)
cat = await Popen(['cat', '-'], stdin=PIPE, stdout=sys.stdout)

echo.stdout.pipe(cat.stdint)

print('cat exited with status code', await cat.returncode)

```


## Worker Threads

For any other calls that are not covered by this library you
can wrap blocing calls in a worker.

```

from libuv
def blocking(i, name):
    # This is not an async sleep! This will block the program

    # This will raise TypeError if i is not an int
    time.sleep(int(i))

    value = "Hello: {}".format(name)
    return value


async def callback():
    nonlocal called

    try:
        value = await worker(blocking, 'Fail', "Tester")
    except TypeError:
        print("caught exception in a thread! cool.")

    value = await worker(blocking, 1, "Tester")

```


