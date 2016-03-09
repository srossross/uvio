from setuptools import setup
from Cython.Build import cythonize
from distutils.extension import Extension

extensions = [
    # Extension("uvio._hello", ["uvio/_hello.pyx"], libraries=['uv']),
    Extension("uvio.loop", ["uvio/loop.pyx"], libraries=['uv']),
    Extension("uvio.handle", ["uvio/handle.pyx"], libraries=['uv']),
    Extension("uvio.idle", ["uvio/idle.pyx"], libraries=['uv']),
]

setup(
  name = 'uvio',
  ext_modules = cythonize(extensions),
)
