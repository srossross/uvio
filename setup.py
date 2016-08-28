from setuptools import setup, find_packages
from Cython.Build import cythonize
from distutils.extension import Extension

import versioneer
import sys
import os

include_dirs = [os.path.join(sys.prefix, "include")]
library_dirs = [os.path.join(sys.prefix, "lib")]
libraries = ["uv"]

kwargs = {
  'include_dirs': include_dirs,
  'library_dirs': library_dirs,
  'libraries': libraries
}
extensions = [
    Extension("uvio._loop", ["uvio/_loop.pyx"], **kwargs),
    Extension("uvio.handle", ["uvio/handle.pyx"], **kwargs),
    Extension("uvio.idle", ["uvio/idle.pyx"], **kwargs),
    Extension("uvio.timer", ["uvio/timer.pyx"], **kwargs),
    Extension("uvio.fs", ["uvio/fs.pyx"], **kwargs),
    Extension("uvio.process", ["uvio/process.pyx"], **kwargs),
    Extension("uvio.stream", ["uvio/stream.pyx"], **kwargs),
    Extension("uvio.workers", ["uvio/workers.pyx"], **kwargs),
    Extension("uvio.net", ["uvio/net.pyx"], **kwargs),
    Extension("uvio.request", ["uvio/request.pyx"], **kwargs),
    Extension("uvio.pipes", ["uvio/pipes.pyx"], **kwargs),
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
