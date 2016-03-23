'''
SSL_read() read unencrypted data which is stored in the input BIO.
SSL_write() write unencrypted data into the output BIO.
BIO_write() write encrypted data into the input BIO.
BIO_read() read encrypted data from the output BIO.
So when do you use what function?

Use BIO_write() to store encrypted data you receive from e.g. a tcp/udp socket. Once you've written to an input BIO, you use SSL_read() to get the unencrypted data, but only after the handshake is ready.
Use BIO_read() to check if there is any data in the output BIO. The output BIO will be filled by openSSL when it's handling the handshake or when you call SSL_write(). When there is data in your output BIO, use BIO_read to get the data and send it to e.g. a client. Use BIO_ctrl_pending() to check how many bytes there are stored in the output bio. See krx_ssl_handle_traffic() in the code listing at the bottom of this post.

'''
import socket
import ssl


sock = socket.create_connection(('google.com', 443))

incoming = ssl.MemoryBIO()
outgoing = ssl.MemoryBIO()

ctx = ssl.create_default_context()

ssl_obj = ctx.wrap_bio(incoming, outgoing)

try:
    # ssl_obj.write(got)
    ssl_obj.do_handshake()
except ssl.SSLWantReadError as err:
    print("err", err)

print('ssl_obj', ssl_obj.pending())
print('incoming', incoming.pending)
print('outgoing', outgoing.pending)

sock.send(outgoing.read())
got = sock.recv(10240)
incoming.write(got)

try:
    # ssl_obj.write(got)
    ssl_obj.do_handshake()
except ssl.SSLWantReadError as err:
    print("err", err)

print('ssl_obj', ssl_obj.pending())
print('incoming', incoming.pending)
print('outgoing', outgoing.pending)


def first_test():
    sock = socket.create_connection(('google.com', 443))

    incoming = ssl.MemoryBIO()
    outgoing = ssl.MemoryBIO()

    ctx = ssl.create_default_context()

    ssl_obj = ctx.wrap_bio(incoming, outgoing)

    try:
        ssl_obj.write(b'')
    except ssl.SSLWantReadError as err:
        print("err", err)

    print('ssl_obj', ssl_obj.pending())
    print('incoming', incoming.pending)
    print('outgoing', outgoing.pending)
    # print()
    # print(outgoing.read())
    data = outgoing.read()
    # print("data", data)
    sock.send(data)


    print('ssl_obj', ssl_obj.pending())
    print('incoming', incoming.pending)
    print('outgoing', outgoing.pending)


    got = sock.recv(10240)
    print('sock.recv got', len(got))

    incoming.write(got)
    # print(incoming.read())
    # print(ssl_obj.read())
    # print('sock.recv', got)


    try:
        # ssl_obj.write(got)
        ssl_obj.do_handshake()
    except ssl.SSLWantReadError as err:
        print("err", err)

    print('ssl_obj', ssl_obj.pending())
    print('incoming', incoming.pending)
    print('outgoing', outgoing.pending)
