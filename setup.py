from setuptools import setup, find_packages
from Cython.Build import cythonize
from distutils.extension import Extension

import versioneer


extensions = [
    Extension("uvio._loop", ["uvio/_loop.pyx"], libraries=['uv']),
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
  url='http://github.com/srossross/uvio',
  version=versioneer.get_version(),
  cmdclass=versioneer.get_cmdclass(),
  ext_modules=cythonize(extensions),
  packages=find_packages(),
  description='asyncio replacement library using libuv',
  author='Sean Ross-Ross',
  author_email='srossross@gmail.com',

)
