import sys
import uvio

async def run_awk():

    date = await uvio.process.Popen(['date'], stdout=uvio.process.PIPE)
    awk = await uvio.process.Popen(['awk', '{print "[AWKED] " $0}'], stdin=uvio.process.PIPE, stdout=sys.stdout)

    date.stdout >> awk.stdin

    date.stdout.pipe(sys.stdout.buffer, end=False)

    print(await awk.returncode)
    print("hello world")

@uvio.sync(timeout=10)
async def main():

    timer = await uvio.set_timeout(run_awk, 1, 1)

    await run_awk()


if __name__ == '__main__':
    main()