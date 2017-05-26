#from distutils.core import setup
#from distutils.extension import Extension
from Cython.Distutils import build_ext

try:
    from setuptools import setup
    from setuptools import Extension
except ImportError:
    from distutils.core import setup
    from distutils.extension import Extension

setup(
  name = 'cagent',
  ext_modules=[
    Extension('cagent', ['cagent.pyx']),
    Extension('processorgroup', ['processorgroup.pyx']),],
  cmdclass = {'build_ext': build_ext}
)
