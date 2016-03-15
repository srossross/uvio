import uvio

async def route(req):
    pass

async def handler(req, res):
    await route(req, res)()
    res.end("Yes")


@uvio.run
async def main():

    server = await uvio.http.listen(handler, host='127.0.0.1', port=80)

    print("server", server)
