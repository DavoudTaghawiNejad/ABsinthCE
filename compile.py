#from distutils.core import setup
#from distutils.extension import Extension
from Cython.Distutils import build_ext
import numpy

try:
    from setuptools import setup
    from setuptools import Extension
except ImportError:
    from distutils.core import setup
    from distutils.extension import Extension
from Cython.Build import cythonize


setup(
  name = 'cagent',
  ext_modules=cythonize([
    Extension('cagent', ['cagent.pyx'],
                 libraries=["zmq"],
                ),
    Extension('processorgroup', ['processorgroup.pyx'],
                 libraries=["zmq"],
                 include_dirs=[numpy.get_include()],
                ),
              ]),
  cmdclass = {'build_ext': build_ext}
)




