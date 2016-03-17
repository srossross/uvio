from setuptools import setup
from Cython.Build import cythonize
from distutils.extension import Extension

extensions = [
    Extension("uvio._hello", ["uvio/_hello.pyx"], libraries=['uv']),
    Extension("uvio.loop", ["uvio/loop.pyx"], libraries=['uv']),
    Extension("uvio.handle", ["uvio/handle.pyx"], libraries=['uv']),
    Extension("uvio.idle", ["uvio/idle.pyx"], libraries=['uv']),
    Extension("uvio.timer", ["uvio/timer.pyx"], libraries=['uv']),
    Extension("uvio.fs", ["uvio/fs.pyx"], libraries=['uv']),
    Extension("uvio.subprocess", ["uvio/subprocess.pyx"], libraries=['uv']),
    Extension("uvio.stream", ["uvio/stream.pyx"], libraries=['uv']),
    Extension("uvio.workers", ["uvio/workers.pyx"], libraries=['uv']),
    Extension("uvio.net", ["uvio/net.pyx"], libraries=['uv']),
    Extension("uvio.request", ["uvio/request.pyx"], libraries=['uv']),
    Extension("uvio.pipes", ["uvio/pipes.pyx"], libraries=['uv']),
]

setup(
  name = 'uvio',
  ext_modules = cythonize(extensions),
)
